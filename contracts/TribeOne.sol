// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/ITribeOne.sol";
import "./libraries/TransferHelper.sol";

contract TribeOne is ERC721Holder, ERC1155Holder, ITribeOne, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    enum Status {
        AVOID_ZERO, // just for avoid zero
        LISTED, // after the loan has been created --> the next status will be APPROVED
        APPROVED, // in this status the loan has a lender -- will be set after approveLoan(). loan fund => borrower
        LOANACTIVED, // NFT was brought from opensea by agent and staked in TribeOne - relayNFT()
        LOANPAID, // loan was paid fully but still in TribeOne
        WITHDRAWN, // the final status, the collateral returned to the borrower or to the lender withdrawNFT()
        FAILED, // NFT buying order was failed in partner's platform such as opensea...
        CANCELLED, // only if loan is LISTED - cancelLoan()
        DEFAULTED, // Grace period = 15 days were passed from the last payment schedule
        LIQUIDATION, // NFT was put in marketplace
        POSTLIQUIDATION, /// NFT was sold
        RESTWITHDRAWN, // user get back the rest of money from the money which NFT set is sold in marketplace
        RESTLOCKED // Rest amount was forcely locked because he did not request to get back with in 2 weeks (GRACE PERIODS)
    }

    struct Asset {
        uint256 amount;
        address currency; // address(0) is BNB native coin
    }

    struct Loan {
        uint256 fundAmount; // the amount which user put in TribeOne to buy NFT
        uint256 paidAmount; // the amount that has been paid back to the lender to date
        uint256 loanStart; // the point when the loan is approved
        uint256 postTime; // the time when NFT set was sold in marketplace and that money was put in TribeOne
        uint256 restAmount; // rest amount after sending loan debt(+interest) and 5% penalty
        address borrower; // the address who receives the loan
        uint8 nrOfPenalty;
        uint8 paidTenors; // the number of tenors which we can consider user passed
        Asset loanAsset;
        Asset collateralAsset;
        Status status; // the loan status
        uint16[] loanRules; // tenor, LTV: 10000 - 100%, interest: 10000 - 100%,
        address[] nftAddressArray; // the adderess of the ERC721
        uint256[] nftTokenIdArray; // the unique identifier of the NFT token that the borrower uses as collateral
        TransferHelper.TokenType[] nftTokenTypeArray; // the token types : ERC721 , ERC1155 , ...
    }

    mapping(uint256 => Loan) public loans; // loanId => Loan
    Counters.Counter public loanIds; // loanId is from No.1
    // uint public loanLength;
    uint256 public constant TENOR_UNIT = 4 weeks; // installment should be pay at least in every 4 weeks
    uint256 public constant GRACE_PERIOD = 14 days; // 2 weeks
    address private agentProxy;
    address public salesManager;
    address public feeTo;
    address public immutable feeCurrency; // stable coin such as USDC, late fee $5
    uint256 public LATE_FEE; // we will set it 5 USD for each tenor late
    uint256 public PENALTY_FEE; // we will set it 5% in the future - 1000 = 100%

    event LoanCreated(uint256 indexed loanId, address indexed owner);
    event LoanApproved(uint256 indexed _loanId, address indexed _to, address _fundCurreny, uint256 _fundAmount);
    event LoanCanceled(uint256 indexed _loanId, address _sender);
    event NFTRelayed(uint256 indexed _loanId, address indexed _sender, bool _accepted);
    event InstallmentPaid(uint256 indexed _loanId, address _sender, address _currency, uint256 _amount);
    event NFTWithdrew(uint256 indexed _loanId, address _to);
    event LoanDefaulted(uint256 indexed _loandId);
    event LoanLiquidation(uint256 indexed _loanId, address _salesManager);
    event LoanPostLiquidation(uint256 indexed _loanId, uint256 _soldAmount, uint256 _finalDebt);
    event RestWithdrew(uint256 indexed _loanId, uint256 _amount);

    constructor(
        address _agentProxy,
        address _salesManger,
        address _feeTo,
        address _feeCurrency
    ) {
        agentProxy = _agentProxy;
        salesManager = _salesManger;
        feeTo = _feeTo;
        feeCurrency = _feeCurrency;
    }

    receive() external payable {}

    /**
     * @dev no allowed proxy, only msg.sender directly
     */
    modifier onlyAgent() {
        require(msg.sender == agentProxy, "TribeOne: Forbidden");
        _;
    }

    function setAgentProxy(address _agentProxy) external onlyOwner {
        agentProxy = _agentProxy;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setLateFee(uint256 _lateFee) external onlyOwner {
        LATE_FEE = _lateFee;
    }

    function setPenalyFee(uint256 _penaltyFee) external onlyOwner {
        PENALTY_FEE = _penaltyFee;
    }

    function setSalesManager(address _salesManager) external onlyOwner {
        salesManager = _salesManager;
    }

    function createLoan(
        uint16[] calldata _loanRules, // tenor, LTV, interest, 10000 - 100% to use array - avoid stack too deep
        address[] calldata _currencies, // _loanCurrency, _collateralCurrency, address(0) is native coin
        address[] calldata nftAddressArray,
        uint256[] calldata _amounts, // _fundAmount, _collateralAmount
        uint256[] calldata nftTokenIdArray,
        TransferHelper.TokenType[] memory nftTokenTypeArray
    ) external payable {
        require(_loanRules.length == 3 && _amounts.length == 2, "TribeOne: Invalid parameter");
        require(_loanRules[1] > 0, "TribeOne: ZERO_VALUE");
        require(_loanRules[0] > 0, "TribeOne: Loan must have at least 1 installment");
        require(nftAddressArray.length > 0, "TribeOne: Loan must have atleast 1 NFT");
        address _collateralCurrency = _currencies[1];
        address _loanCurrency = _currencies[0];

        require(_loanCurrency != _collateralCurrency, "TribeOne: Wrong assets");

        require(
            nftAddressArray.length == nftTokenIdArray.length && nftTokenIdArray.length == nftTokenTypeArray.length,
            "TribeOne: NFT provided informations are missing or incomplete"
        );

        loanIds.increment();
        uint256 loanID = loanIds.current();

        // Transfer Collateral and PreFund from sender to contract
        uint256 _fundAmount = _loanCurrency == address(0) ? msg.value : _amounts[0];
        uint256 _collateralAmount = _collateralCurrency == address(0) ? msg.value : _amounts[1];

        if (_loanCurrency != address(0)) {
            TransferHelper.safeTransferFrom(_loanCurrency, _msgSender(), address(this), _fundAmount);
        }
        if (_collateralCurrency != address(0)) {
            TransferHelper.safeTransferFrom(_collateralCurrency, _msgSender(), address(this), _collateralAmount);
        }

        loans[loanID].nftAddressArray = nftAddressArray;
        loans[loanID].borrower = _msgSender();
        loans[loanID].loanAsset = Asset({currency: _loanCurrency, amount: 0});
        loans[loanID].collateralAsset = Asset({currency: _collateralCurrency, amount: _collateralAmount});
        loans[loanID].loanRules = _loanRules;
        loans[loanID].nftTokenIdArray = nftTokenIdArray;
        loans[loanID].fundAmount = _fundAmount;

        loans[loanID].status = Status.LISTED;
        loans[loanID].nftTokenTypeArray = nftTokenTypeArray;

        emit LoanCreated(loanID, msg.sender);
    }

    function approveLoan(
        uint256 _loanId,
        uint256 _amount,
        address _agent
    ) external override onlyAgent nonReentrant {
        require(loans[_loanId].status == Status.LISTED, "TribeOne: Invalid request");

        loans[_loanId].status = Status.APPROVED;
        address _token = loans[_loanId].loanAsset.currency;

        loans[_loanId].loanAsset.amount = _amount - loans[_loanId].fundAmount;

        if (_token == address(0)) {
            require(address(this).balance >= _amount, "TribeOne: Insufficient fund");
            TransferHelper.safeTransferETH(_agent, _amount);
        } else {
            require(IERC20(_token).balanceOf(address(this)) >= _amount, "TribeOne: Insufficient fund");
            TransferHelper.safeTransfer(_token, _agent, _amount);
        }

        emit LoanApproved(_loanId, _agent, _token, _amount);
    }

    /**
     * @dev _loanId: loanId, _accepted: order to Partner is succeeded or not
     * loan will be back to TribeOne if accepted is false
     */
    function relayNFT(
        uint256 _loanId,
        address _agent,
        bool _accepted
    ) external payable override onlyAgent nonReentrant {
        if (_accepted) {
            require(loans[_loanId].status == Status.APPROVED, "TribeOne: Not approved loan");

            uint256 len = loans[_loanId].nftAddressArray.length;
            for (uint256 ii = 0; ii < len; ii++) {
                TransferHelper.safeTransferNFT(
                    loans[_loanId].nftAddressArray[ii],
                    _agent,
                    address(this),
                    loans[_loanId].nftTokenTypeArray[ii],
                    loans[_loanId].nftTokenIdArray[ii]
                );
            }

            loans[_loanId].status = Status.LOANACTIVED;
            loans[_loanId].loanStart = block.timestamp;
        } else {
            loans[_loanId].status = Status.FAILED;
            // refund loan
            // in the case when loan currency is ETH, loan amount should be fund back from agent to TribeOne
            address _token = loans[_loanId].loanAsset.currency;
            uint256 _amount = loans[_loanId].loanAsset.amount;
            if (_token == address(0)) {
                require(msg.value >= _amount, "TribeOne: Less than loan amount");
                if (msg.value > _amount) {
                    TransferHelper.safeTransferETH(_agent, msg.value - _amount);
                }
            } else {
                TransferHelper.safeTransferFrom(_token, _agent, address(this), _amount);
            }

            returnColleteral(_loanId);
            returnFund(_loanId);
        }

        emit NFTRelayed(_loanId, _agent, _accepted);
    }

    function payInstallment(uint256 _loanId, uint256 _amount) external payable nonReentrant {
        Loan memory _loan = loans[_loanId];
        require(_loan.status == Status.LOANACTIVED || _loan.status == Status.DEFAULTED, "TribeOne: Invalid status");
        uint256 expectedNr = expectedNrOfPayments(_loanId);

        address _loanCurrency = _loan.loanAsset.currency;
        if (_loanCurrency == address(0)) {
            _amount = msg.value;
        }

        uint256 paidAmount = _loan.paidAmount;
        uint256 _totalDebt = totalDebt(_loanId);
        {
            // uint16[] calldata _loanRules, // tenor, LTV, interest,
            uint256 expectedAmount = (_totalDebt * expectedNr) / _loan.loanRules[0];
            require(paidAmount + _amount >= expectedAmount, "TribeOne: Insufficient Amount");
            // out of rule, penalty
            updatePenalty(_loanId);
        }

        // Transfer asset from msg.sender to contract
        uint256 dust;
        if (paidAmount + _amount > _totalDebt) {
            dust = paidAmount + _amount - _totalDebt;
        }
        _amount -= dust;
        // NOTE - don't merge two conditions
        if (_loanCurrency == address(0)) {
            if (dust > 0) {
                TransferHelper.safeTransferETH(_msgSender(), dust);
            }
        } else {
            TransferHelper.safeTransferFrom(_loanCurrency, _msgSender(), address(this), _amount);
        }

        loans[_loanId].paidAmount += _amount;
        loans[_loanId].paidTenors = uint8((loans[_loanId].paidAmount * _loan.loanRules[0]) / _totalDebt);

        if (loans[_loanId].status == Status.DEFAULTED) {
            loans[_loanId].status = Status.LOANACTIVED;
        }

        // If user is borrower and loan is paid whole amount and he has no late_fee, give back NFT here directly
        // else borrower should call withdraw manually himself
        // We should check conditions first to avoid transaction failed
        if (paidAmount + _amount == _totalDebt) {
            loans[_loanId].status = Status.LOANPAID;
            if (_loan.borrower == _msgSender() && _loan.nrOfPenalty == 0) {
                _withdrawNFT(_loanId);
            }
        }

        emit InstallmentPaid(_loanId, msg.sender, _loanCurrency, _amount);
    }

    function withdrawNFT(uint256 _loanId) public nonReentrant {
        _withdrawNFT(_loanId);
    }

    function _withdrawNFT(uint256 _loanId) private {
        Loan memory _loan = loans[_loanId];
        address _sender = _msgSender();
        require(_sender == _loan.borrower, "TribeOne: Forbidden");
        require(_loan.status == Status.LOANPAID, "TribeOne: Invalid status - you have still debt to pay");
        loans[_loanId].status = Status.WITHDRAWN;

        if (_loan.nrOfPenalty > 0) {
            uint256 _totalLateFee = _loan.nrOfPenalty * LATE_FEE * IERC20Metadata(feeCurrency).decimals();
            TransferHelper.safeTransferFrom(feeCurrency, _sender, address(feeTo), _totalLateFee);
        }

        uint256 len = _loan.nftAddressArray.length;
        for (uint256 ii = 0; ii < len; ii++) {
            address _nftAddress = _loan.nftAddressArray[ii];
            uint256 _tokenId = _loan.nftTokenIdArray[ii];
            TransferHelper.safeTransferNFT(_nftAddress, address(this), _sender, _loan.nftTokenTypeArray[ii], _tokenId);
        }

        returnColleteral(_loanId);
        emit NFTWithdrew(_loanId, _sender);
    }

    function updatePenalty(uint256 _loanId) public {
        Loan memory _loan = loans[_loanId];
        require(_loan.status == Status.LOANACTIVED || _loan.status == Status.DEFAULTED, "TribeOne: Not actived loan");
        uint256 expectedNr = expectedNrOfPayments(_loanId);
        if (expectedNr > loans[_loanId].paidTenors) {
            loans[_loanId].nrOfPenalty += uint8(expectedNr - loans[_loanId].paidTenors);
        }
    }

    function totalDebt(uint256 _loanId) public view returns (uint256) {
        return (loans[_loanId].loanAsset.amount * (10000 + loans[_loanId].loanRules[2])) / 10000;
    }

    /**
     *@dev when user in Tenor 2 (from tenor 1 to tenor 2, we expect at least one time payment)
     */
    function expectedNrOfPayments(uint256 _loanId) public view returns (uint256) {
        uint256 loanStart = loans[_loanId].loanStart;
        uint256 _expected = (block.timestamp - loanStart) / TENOR_UNIT;
        uint256 _tenor = loans[_loanId].loanRules[0];
        return _expected > _tenor ? _tenor : _expected;
    }

    function expectedLastPaymentTime(uint256 _loanId) public view returns (uint256) {
        return loans[_loanId].loanStart + TENOR_UNIT * (loans[_loanId].paidTenors + 1);
    }

    function setLoanDefaulted(uint256 _loanId) external nonReentrant {
        require(loans[_loanId].status == Status.LOANACTIVED, "TribeOne: Invalid status");
        require(expectedLastPaymentTime(_loanId) < block.timestamp, "TribeOne: Not overdued date yet");
        updatePenalty(_loanId);
        loans[_loanId].status = Status.DEFAULTED;

        emit LoanDefaulted(_loanId);
    }

    function setLoanLiquidation(uint256 _loanId) external nonReentrant {
        Loan memory _loan = loans[_loanId];
        require(_loan.status == Status.DEFAULTED, "TribeOne: Invalid status");
        require(expectedLastPaymentTime(_loanId) + GRACE_PERIOD < block.timestamp, "TribeOne: Not overdued date yet");
        loans[_loanId].status = Status.LIQUIDATION;
        uint256 len = _loan.nftAddressArray.length;

        // Transfering NFTs first
        for (uint256 ii = 0; ii < len; ii++) {
            address _nftAddress = _loan.nftAddressArray[ii];
            uint256 _tokenId = _loan.nftTokenIdArray[ii];
            TransferHelper.safeTransferNFT(_nftAddress, address(this), salesManager, _loan.nftTokenTypeArray[ii], _tokenId);
        }
        // user can not get back Collateral in this case
        address _currency = _loan.collateralAsset.currency;
        uint256 _amount = _loan.collateralAsset.amount;
        TransferHelper.safeTransferAsset(_currency, feeTo, _amount);

        emit LoanLiquidation(_loanId, salesManager);
    }

    /**
     * @dev after sold NFT set in market place, and give that fund back to TribeOne
     * Only sales manager can do this
     */
    function postLiquidation(uint256 _loanId, uint256 _amount) external payable nonReentrant {
        require(_msgSender() == salesManager, "TribeOne: Forbidden");
        Loan memory _loan = loans[_loanId];
        require(_loan.status == Status.LIQUIDATION, "TribeOne: invalid status");

        // We collect fees to our feeTo address
        address _currency = _loan.loanAsset.currency;
        _amount = _currency == address(0) ? msg.value : _amount;
        uint256 _finalDebt = finalDebtAndPenalty(_loanId);
        if (_currency == address(0)) {
            _finalDebt = _amount > _finalDebt ? _finalDebt : _amount;
            TransferHelper.safeTransferETH(feeTo, _finalDebt);
        } else {
            TransferHelper.safeTransferFrom(_currency, _msgSender(), address(this), _amount);
            _finalDebt = _amount > _finalDebt ? _finalDebt : _amount;
            TransferHelper.safeTransfer(_currency, feeTo, _finalDebt);
        }

        loans[_loanId].status = Status.POSTLIQUIDATION;
        if (_amount > _finalDebt) {
            loans[_loanId].restAmount = _amount - _finalDebt;
        }
        loans[_loanId].postTime = block.timestamp;
        emit LoanPostLiquidation(_loanId, _amount, _finalDebt);
    }

    function finalDebtAndPenalty(uint256 _loanId) public view returns (uint256) {
        Loan memory _loan = loans[_loanId];
        uint256 paidAmount = _loan.paidAmount;
        uint256 _totalDebt = totalDebt(_loanId);
        uint256 _penalty = (_loan.loanAsset.amount * PENALTY_FEE) / 1000; // 5% penalty of loan amount
        return _totalDebt + _penalty - paidAmount;
    }

    /**
     * @dev User can get back the rest money through this function, but he should pay late fee.
     */
    function getBackFund(uint256 _loanId) external payable {
        Loan memory _loan = loans[_loanId];
        require(_msgSender() == _loan.borrower, "TribOne: Forbidden");
        require(_loan.status == Status.POSTLIQUIDATION, "TribeOne: Invalid status");
        require(_loan.postTime + GRACE_PERIOD > block.timestamp, "TribeOne: Time over");
        uint256 _restAmount = _loan.restAmount;
        require(_restAmount > 0, "TribeOne: No amount to give back");
        uint256 _amount = LATE_FEE * (10**IERC20Metadata(feeCurrency).decimals()); // tenor late fee
        loans[_loanId].status = Status.RESTWITHDRAWN;
        TransferHelper.safeTransferFrom(feeCurrency, _msgSender(), address(this), _amount);

        address _currency = _loan.loanAsset.currency;

        if (_currency == address(0)) {
            TransferHelper.safeTransferETH(_msgSender(), _restAmount);
        } else {
            TransferHelper.safeTransferFrom(_currency, address(this), _msgSender(), _restAmount);
        }

        emit RestWithdrew(_loanId, _restAmount);
    }

    /**
     * @dev if user does not want to get back rest of money due to some reasons, such as gas fee...
     * we will transfer rest money to our fee address (after 14 days notification).
     * For saving gas fee, we will transfer once for the one kind of token.
     */

    function lockRestAmount(uint256[] calldata _loanIds, address _currency) external nonReentrant {
        uint256 len = _loanIds.length;
        uint256 _amount = 0;
        for (uint256 ii = 0; ii < len; ii++) {
            uint256 _loanId = _loanIds[ii];
            Loan memory _loan = loans[_loanId];
            if (
                _loan.loanAsset.currency == _currency &&
                _loan.status == Status.POSTLIQUIDATION &&
                _loan.postTime + GRACE_PERIOD > block.timestamp
            ) {
                _amount += _loan.restAmount;
                loans[_loanId].status = Status.RESTLOCKED;
            }
        }

        TransferHelper.safeTransferAsset(_currency, feeTo, _amount);
    }

    function cancelLoan(uint256 _loanId) external nonReentrant {
        Loan memory _loan = loans[_loanId];
        require(_loan.borrower == _msgSender() && _loan.status == Status.LISTED, "TribeOne: Forbidden");
        loans[_loanId].status = Status.CANCELLED;
        returnColleteral(_loanId);
        emit LoanCanceled(_loanId, _msgSender());
    }

    /**
     * @dev return back collateral to borrower due to some reasons
     */
    function returnColleteral(uint256 _loanId) private {
        Loan memory _loan = loans[_loanId];
        address _currency = _loan.collateralAsset.currency;
        uint256 _amount = _loan.collateralAsset.amount;
        address _to = _loan.borrower;
        TransferHelper.safeTransferAsset(_currency, _to, _amount);
    }

    function returnFund(uint256 _loanId) private {
        Loan memory _loan = loans[_loanId];
        address _currency = _loan.loanAsset.currency;
        uint256 _amount = _loan.loanAsset.amount;
        address _to = _loan.borrower;
        TransferHelper.safeTransferAsset(_currency, _to, _amount);
    }
}
