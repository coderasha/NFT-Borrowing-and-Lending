// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./libraries/TransferHelper.sol";

contract TribeOne is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    // using SafeMath for uint256;

    enum Status {
        LISTED, // after the loan have been created --> the next status will be APPROVED
        APPROVED, // in this status the loan has a lender -- will be set after approveLoan(). loan fund => borrower
        DEFAULTED, // NFT was put in market place because user did not keep rule
        LOANACTIVED, // NFT was brought from opensea by agent and staked in TribeOne - relayNFT()
        FAILED, // NFT buying order was failed in partner's platform such as opensea...
        CANCELLED, // only if loan is LISTED - cancelLoan()
        LOANPAID, // loan was paid fully but still in TribeOne
        LIQUIDATION, // NFT was put in marketplace
        POSTLIQUIDATION, /// NFT was sold
        WITHDRAWN // the final status, the collateral returned to the borrower or to the lender withdrawNFT()
    }
    enum TokenType {
        ERC721,
        ERC1155
    }

    mapping(address => bool) private WHITE_LIST;

    struct Asset {
        uint256 amount;
        address currency; // address(0) is BNB native coin
    }

    struct Loan {
        uint256 fundAmount; // the amount which user put in TribeOne to buy NFT
        uint256 nrOfPayments; // the number of installments paid
        uint256 paidAmount; // the amount that has been paid back to the lender to date
        uint8 lastPenaltyTenor;
        uint256 loanStart; // the point when the loan is approved
        uint8 nrOfPenalty;
        uint256 defaultingLimit; // the number of installments allowed to be missed without getting defaulted
        address borrower; // the address who receives the loan
        Asset loanAsset;
        Asset collateralAsset;
        uint16[] loanRules; // tenor, LTV: 10000 - 100%, interest: 10000 - 100%,
        Status status; // the loan status
        address[] nftAddressArray; // the adderess of the ERC721
        uint256[] nftTokenIdArray; // the unique identifier of the NFT token that the borrower uses as collateral
        TokenType[] nftTokenTypeArray; // the token types : ERC721 , ERC1155 , ...
    }

    // loanId => Loan
    mapping(uint256 => Loan) public loans;
    Counters.Counter private loanIds;

    uint256 public TENOR_UNIT = 4 weeks; // installment should be pay at least in every 4 weeks

    event LoanCreated(uint256 indexed loanId, address indexed owner, Status status);
    event LoanApproved(uint256 indexed _loanId, address indexed _to, address _fundCurreny, uint256 _fundAmount);
    event LoanCanceled(uint256 indexed _loanId, address _sender);
    event NFTRelayed(uint256 indexed _loanId, address indexed _sender, bool _accepted);
    event InstallmentPaid(uint256 indexed _loanId, address _sender, address _currency, uint256 _amount);
    event NFTWithdrew(uint256 indexed _loanId, address _to);

    constructor() {}

    /**
     * @dev no allowed proxy, only msg.sender directly
     */
    modifier onlyAgent() {
        require(WHITE_LIST[msg.sender], "TribeOne: Forbidden");
        _;
    }

    function addAgent(address _agent) external onlyOwner {
        WHITE_LIST[_agent] = true;
    }

    function createLoan(
        uint16[] calldata _loanRules, // tenor, LTV, interest, 10000 - 100% to avoid stack too deep
        address[] calldata _currencies, // _loanCurrency, _collateralCurrency
        address[] calldata nftAddressArray,
        uint256[] calldata _amounts, // _fundAmount, _collateralAmount
        uint256[] calldata nftTokenIdArray,
        TokenType[] memory nftTokenTypeArray
    ) external payable {
        require(_loanRules.length == 3 && _amounts.length == 2, "TribeOne: Invalid parameter");
        require(_loanRules[1] > 0, "TribeOne: ZERO_VALUE");
        require(_loanRules[0] > 0, "TribeOne: Loan must have at least 1 installment");
        require(nftAddressArray.length > 0, "TribeOne: Loan must have atleast 1 NFT");

        require(
            nftAddressArray.length == nftTokenIdArray.length && nftTokenIdArray.length == nftTokenTypeArray.length,
            "TribeOne: NFT provided informations are missing or incomplete"
        );

        uint256 loanID = loanIds.current();

        // Computing the defaulting limit
        // if ( _tenor <= 3 )
        //     loans[loanID].defaultingLimit = 1;
        // else if ( _tenor <= 5 )
        //     loans[loanID].defaultingLimit = 2;
        // else if ( _tenor >= 6 )
        //     loans[loanID].defaultingLimit = 3;

        // Transfer Collateral from sender to contract
        // Refund ETH, if any
        if (_currencies[1] == address(0) && msg.value > _amounts[1]) {
            TransferHelper.safeTransferETH(_msgSender(), msg.value - _amounts[1]);
        } else {
            TransferHelper.safeTransferFrom(_currencies[1], _msgSender(), address(this), _amounts[1]);
        }

        loans[loanID].nftAddressArray = nftAddressArray;
        loans[loanID].borrower = _msgSender();
        loans[loanID].loanAsset = Asset({
            currency: _currencies[0],
            amount: 0
        });
        loans[loanID].collateralAsset = Asset({
            currency: _currencies[1],
            amount: _amounts[1]
        });
        loans[loanID].loanRules = _loanRules;
        loans[loanID].nftTokenIdArray = nftTokenIdArray;
        loans[loanID].fundAmount = _amounts[0];

        
        loans[loanID].status = Status.LISTED;
        loans[loanID].nftTokenTypeArray = nftTokenTypeArray;
        loanIds.increment();
        // Emit event
        emit LoanCreated(loanID, msg.sender, Status.LISTED);
    }

    /**
     * @dev _loandId: loandId, _token: currency of NFT,
     * @dev we validate loan in backend side
     */
    function approveLoan(uint256 _loanId, uint256 _amount) external onlyAgent nonReentrant {
        require(loans[_loanId].status == Status.LISTED, "TribeOne: Invalid request");

        loans[_loanId].status = Status.APPROVED;
        address _token = loans[_loanId].loanAsset.currency;

        loans[_loanId].loanAsset.amount = _amount - loans[_loanId].fundAmount;

        if (_token == address(0)) {
            require(address(this).balance >= _amount, "TribeOne: Insufficient fund");
            TransferHelper.safeTransferETH(msg.sender, _amount);
        } else {
            require(IERC20(_token).balanceOf(address(this)) >= _amount, "TribeOne: Insufficient fund");
            TransferHelper.safeTransfer(_token, msg.sender, _amount);
        }

        emit LoanApproved(_loanId, msg.sender, _token, _amount);
    }

    /**
     * @dev _loanId: loanId, _accepted: order to Partner is succeeded or not
     * TODO check - if accepted is not true, should we give back loan collateral to user?
     * loan will be back to TribeOne if accepted false
     */
    function relayNFT(uint256 _loanId, bool _accepted) external payable onlyAgent nonReentrant {
        // Saving for gas
        Loan memory _loan = loans[_loanId];
        if (_accepted) {
            require(_loan.status == Status.APPROVED, "TribeOne: Not approved loan");

            uint256 len = _loan.nftAddressArray.length;
            for (uint256 ii = 0; ii < len; ii++) {
                address _nftAddress = _loan.nftAddressArray[ii];
                uint256 _tokenId = _loan.nftTokenIdArray[ii];

                // ERC721 case
                if (_loan.nftTokenTypeArray[ii] == TokenType.ERC721) {
                    // msg.sender is the owner of
                    IERC721(_nftAddress).safeTransferFrom(_msgSender(), address(this), _tokenId);
                } else {
                    // ERC1155 case
                    IERC1155(_nftAddress).safeTransferFrom(_msgSender(), address(this), _tokenId, 1, "0x00");
                }
            }

            loans[_loanId].status = Status.LOANACTIVED;
            loans[_loanId].loanStart = block.timestamp;
        } else {
            loans[_loanId].status = Status.FAILED;
            // refund loan
            // in the case when loan currency is ETH, loan is fund back by msg.sender
            address _token = _loan.loanAsset.currency;
            uint _amount = _loan.loanAsset.amount;
            if (_token == address(0)) {
                require(msg.value - _amount >= 0, "TribeOne: Less than loan amount");
                if (msg.value > _amount) {
                    TransferHelper.safeTransferETH(_msgSender(), msg.value - _amount);
                }
            } else {
                TransferHelper.safeTransferFrom(_token, _msgSender(), address(this), _amount);
            }
            returnColleteral(_loanId);
        }

        emit NFTRelayed(_loanId, msg.sender, _accepted);
    }

    function payInstallment(uint256 _loanId, uint256 _amount) external payable {
        // Just for saving gas
        Loan memory _loan = loans[_loanId];
        require(_loan.status == Status.LOANACTIVED, "TribeOne: Not actived loan");
        uint256 _nrOfPayments = _loan.nrOfPayments;
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
        }

        // Transfer asset from msg.sender to contract
        uint256 dust;
        unchecked {
            dust = paidAmount + _amount - _totalDebt;
        }

        if (_loanCurrency == address(0)) {
            if (dust > 0) {
                TransferHelper.safeTransferETH(_msgSender(), dust);
            }
        } else {
            TransferHelper.safeTransferFrom(_loanCurrency, _msgSender(), address(this), _amount - dust);
        }

        // out of rule, penalty
        if (expectedNr > _nrOfPayments + 1) {
            loans[_loanId].nrOfPenalty = uint8(expectedNr - (_nrOfPayments + 1));
            loans[_loanId].lastPenaltyTenor = uint8(expectedNr);
        }

        loans[_loanId].paidAmount += _amount;
        loans[_loanId].nrOfPayments += 1;

        // If user is borrower and loan is paid whole amount  transfer here directly
        // else borrower should call withdraw manually himself
        // We should check conditions first to avoid transaction failed
        if (paidAmount + _amount == _totalDebt && _loan.borrower == _msgSender()) {
            withdrawNFT(_loanId);
        }

        emit InstallmentPaid(_loanId, msg.sender, _loanCurrency, _amount);
    }

    function totalDebt(uint256 _loanId) public view returns (uint256) {
        Loan memory _loan = loans[_loanId];
        // return (_loan.loanAmount * (10000 + _loan.loanRules[2])) / 10000;
        return (_loan.loanAsset.amount * (10000 + _loan.loanRules[2])) / 10000;
    }

    function expectedNrOfPayments(uint256 _loanId) public view returns (uint256) {
        uint256 loanStart = loans[_loanId].loanStart;
        return (block.timestamp - loanStart) / TENOR_UNIT + 1;
    }

    function withdrawNFT(uint256 _loanId) public nonReentrant {
        Loan memory _loan = loans[_loanId];
        require(_msgSender() == _loan.borrower, "TribeOne: Forbidden");
        require(_loan.paidAmount == totalDebt(_loanId), "TribeOne: Still debt");

        // TODO should check penalty and apply

        uint256 len = _loan.nftAddressArray.length;
        for (uint256 ii = 0; ii < len; ii++) {
            address _nftAddress = _loan.nftAddressArray[ii];
            uint256 _tokenId = _loan.nftTokenIdArray[ii];
            // We assume only ERC721 case first
            // ERC721 case
            if (_loan.nftTokenTypeArray[ii] == TokenType.ERC721) {
                IERC721(_nftAddress).safeTransferFrom(address(this), _msgSender(), _tokenId);
            } else {
                // ERC1155 case
                IERC721(_nftAddress).safeTransferFrom(address(this), _msgSender(), _tokenId);
            }
        }

        loans[_loanId].status = Status.WITHDRAWN;

        returnColleteral(_loanId);

        emit NFTWithdrew(_loanId, _msgSender());
    }

    function cancelLoan(uint256 _loanId) external nonReentrant {
        Loan memory _loan = loans[_loanId];
        require(_loan.borrower == _msgSender() && _loan.status == Status.LISTED, "TribeOne: Forbidden");
        loans[_loanId].status = Status.CANCELLED;

        returnColleteral(_loanId);

        emit LoanCanceled(_loanId, _msgSender());
    }

    // /**
    //  * @dev return back collateral to borrower due to some reasons
    //  * such as canceled order in opensea, or canncel loan, withdraw NFT
    //  */
    function returnColleteral(uint256 _loanId) private {
        Loan memory _loan = loans[_loanId];
        address _currency = _loan.collateralAsset.currency;
        uint256 _amount = _loan.collateralAsset.amount;
        address _to = _loan.borrower;
        if (_currency == address(0)) {
            TransferHelper.safeTransferETH(_to, _amount);
        } else {
            TransferHelper.safeTransfer(_currency, _to, _amount);
        }
    }
}
