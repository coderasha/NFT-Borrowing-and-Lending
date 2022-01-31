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
  - TWAP ORACLE FACTORY: 0x6fa8a7E5c13E4094fD4Fa288ba59544791E4c9d3
  - WETH_HAKA 0x953c559c522513b5fc7f806655f16347d465d1f1
  - TWAP_ORACLE WETH_HAKA: 0xcB4e20963ef1B6384126dCeBA8579683a205C5f6
  - TWAP_ORACLE WETH_USDC(0xc778417e063141139fce010982780140aa0cd5ab_0xD4D5c5D939A173b9c18a6B72eEaffD98ecF8b3F6): 0xc86718f161412Ace9c0dC6F81B26EfD4D3A8F5e0

  - MultiSigWallet: 0x8Ff48A7EAE9243486212F4a024C7e2fff563b131
  - AssetManager: 0x4Ea17a52482C1d45cC62617D32DA2A4349e18a4b
  - HAKA: 0xd8f50554055Be0276fa29F40Fb3227FE96B5D6c2
  - TribeOne: 0x9165C2D57F825CFbF8306EB97eEe6E2eAd56adc7
  - AirdropTribeOne: 0x6F971B269B0e3b814529B802F080a27f13721E67

## Deployment guide
  - Add HAKA as available asset in AssetManager
  - Set TribeOne as consumer in AssetManager
  - Send some ETH to AssetManager
  - Add admins in TribeOne
  - setAllowanceForAssetManager

## Mainnet deployment
  - Source code commit: https://github.com/TribeOneDefi/TribeOne-NFT-Loan-Contract/tree/cbc1190ef6fcea7de4466f0b2b3bd7391912efee
  - TWAP ORACLE FACTORY: 0xd4354a2e9a5b29c0db8c22f500d8bbacaa257deb
  - WETH_HAKA:0xc5BbE611A5A0Ee224ABF7ad959C11aAd3b875957 (0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2-0xd85ad783cc94bd04196a13dc042a3054a9b52210)
  - TWAP_ORACLE WETH_HAKA: 0x0d89a47c2177c956cc8e93a6b0e4650cfc606034
  - TWAP_ORACLE USDC_WETH(0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 - 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2): 0x6fa510b6027ddda59c1c4639e2bd4ec863a4e90f
  - HAKA: 0xd85ad783cc94bd04196a13dc042a3054a9b52210

  Enabled optimization with runs 200. compiler: 0.8.0
  - AssetManager: 0xb4cac63240db2742095fd4487aac9b780f5a5c9e
  - TribeOne: 0x71cb5ce3b51886aa7d3423f774890a78a8245aef
  - MultiSigWallet: 0x75107da357d5b659ed229e6a1e71d0055b30dbbd
