# TribeOne NFT Loan Smart contract

- TribeOne is the platform which loan digital assets for borrower to purchase NFT items from other partner's platforms.

## Diagram flow
- Borrower requests to create loan with collateral. He can select the type of loan.
- Once loan is requested, admin will approve loan and our agent account buy requested NFT items from Partner's platform and stake it in TribeOne.
  If loan is not valid type, we will notify for use to cancel it.
- Staking NFT items, user should pay installments according to loan rule.
- If user would pay all installment with out any rule out, he can withdraw NFT items and callateral in the final payment.

### Ruled out users
- Once user missed one or any scheduled payment data, we will notify users via email.
- If there's no any reply from user during predefined period(14days for now), we will transfer NFT items to marketplace to sell it. (At that time, we lock collateral forever)
- After selling NFT items in marketplace, our sale manager transfer fund to TribeOne.
- TribeOne will reduce user's debt (loan, interest, penalty, late fee), and notify for user to withdraw the rest, if any. (for predefined period 14days for now)
- If user would not get back in predefined period(14 days), Tribe will lock the rest of money.    

``bash
Note: We set late fee and final penaly as 0 at the first stage.
``

### Deployment
- Once deploying TribeOne, we transfer ownership to MultiSigWallet


### Assets store
  - User
    collateral: TribeOne
    fund amount: TribeOne
    installment payment: Asset Manager
  - Admin
    Asset Manager


=== Rinkeby testnet deploy ===
deploying "MultiSigWallet": deployed at 0x75415C1a0fCE7A5E9D0cB3c6f359A9F2E2D812e4 with 1263390 gas
deploying "AssetManager": deployed at 0x997036a4DC288C7d0C7C570e61dCdb54F0a3d6B2 with 1183551 gas
reusing "MockERC20" at 0xd8f50554055Be0276fa29F40Fb3227FE96B5D6c2
deploying "TribeOne": deployed at 0xeaB917ADb2DD2988D4F62637AB1e6010601252dd with 3796318 gas