const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

async function deployBase() {
    const [
        owner, 
        alice, 
        bob, 
        charlie, 
        david, 
        eve,
        frank,
        buyer,
        commissionReceiver
    ] = await ethers.getSigners();

    

    const ReleaseManagerFactoryF = await ethers.getContractFactory("ReleaseManagerFactory");
    const ReleaseManagerF = await ethers.getContractFactory("@intercoin/releasemanager/contracts/ReleaseManager.sol:ReleaseManager");
    const NFTFactoryF = await ethers.getContractFactory("NFTFactory");
    const NFTF = await ethers.getContractFactory("NFT");
    const NFTStateF = await ethers.getContractFactory("NFTState");
    const NFTViewF = await ethers.getContractFactory("NFTView");
    //const CostManagerFactory = await ethers.getContractFactory("MockCostManager");
    const ERC20F = await ethers.getContractFactory("MockERC20");
    const MockUsefulContractF = await ethers.getContractFactory("MockUsefulContract");
    //const BuyerF = await ethers.getContractFactory("Buyer");
    // const CostManagerGoodF = await ethers.getContractFactory("MockCostManagerGood");
    // const CostManagerBadF = await ethers.getContractFactory("MockCostManagerBad");
    // const NFTSalesF = await ethers.getContractFactory("NFTSales");
    // const NFTSalesFactoryF = await ethers.getContractFactory("NFTSalesFactory");
    // const BadNFTSaleF = await ethers.getContractFactory("BadNFTSale");

    // const HookF = await ethers.getContractFactory("MockHook");
    // const BadHookF = await ethers.getContractFactory("MockBadHook");
    // const FalseHookF = await ethers.getContractFactory("MockFalseHook");
    // const NotSupportingHookF = await ethers.getContractFactory("MockNotSupportingHook");
    // const WithoutFunctionHookF = await ethers.getContractFactory("MockWithoutFunctionHook");
    // const MockCommunityF = await ethers.getContractFactory("MockCommunity");

    
    const AuctionFactoryF = await ethers.getContractFactory("AuctionFactory");
    const AuctionF = await ethers.getContractFactory("Auction");
    const AuctionCommunityF = await ethers.getContractFactory("AuctionCommunity");
    const AuctionNFTF = await ethers.getContractFactory("AuctionNFT");
    const AuctionSubscriptionF = await ethers.getContractFactory("AuctionSubscription");
    

    const nftState = await NFTStateF.deploy();
    const nftView = await NFTViewF.deploy();
    const nftImpl = await NFTF.deploy();

    const AuctionImpl = await AuctionF.deploy();
    const AuctionCommunityImpl = await AuctionCommunityF.deploy();
    const AuctionNFTImpl = await AuctionNFTF.deploy();
    const AuctionSubscriptionImpl = await AuctionSubscriptionF.deploy();

    const implementationReleaseManager = await ReleaseManagerF.deploy();
    //const nftsale_implementation = await NFTSalesF.connect(owner).deploy();
    

    let releaseManagerFactory = await ReleaseManagerFactoryF.connect(owner).deploy(implementationReleaseManager.target);
    let tx,rc,event,instance,instancesCount;
    //
    tx = await releaseManagerFactory.connect(owner).produce();
    rc = await tx.wait(); // 0ms, as tx is already confirmed
    event = rc.logs.find(event => event.fragment && event.fragment.name === 'InstanceProduced');
    [instance, instancesCount] = event.args;
    // const releaseManager = await ethers.getContractAt("ReleaseManager",instance);
    const releaseManager = await ethers.getContractAt("@intercoin/releasemanager/contracts/ReleaseManager.sol:ReleaseManager",instance);
    

    
    const TOTALSUPPLY = ethers.parseEther('1000000000');    
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
    const DEAD_ADDRESS = '0x000000000000000000000000000000000000dEaD';
    const contractURI = "https://contracturi";
    const SERIES_BITS = 192n;
    const NO_COSTMANAGER = ZERO_ADDRESS;

    //const costManager = await CostManagerFactory.deploy();
    const mockUsefulContract = await MockUsefulContractF.deploy();
    
    const erc20 = await ERC20F.deploy("ERC20 Token", "ERC20");

    // const costManagerGood = await CostManagerGoodF.deploy();
    // const costManagerBad = await CostManagerBadF.deploy();

    // const nftSaleFactory = await NFTSalesFactoryF.connect(owner).deploy(nftsale_implementation.target);
    // const badNFTSale = await BadNFTSaleF.deploy();
   
    // const hook1 = await HookF.deploy();
    // const hook2 = await HookF.deploy();
    // const hook3 = await HookF.deploy();
    // const badHook = await BadHookF.deploy();
    // const falseHook = await FalseHookF.deploy();
    // const notSupportingHook = await NotSupportingHookF.deploy();
    // const withoutFunctionHook = await WithoutFunctionHookF.deploy();
    // const mockCommunity = await MockCommunityF.deploy();

    await erc20.mint(owner.address, TOTALSUPPLY);
    await erc20.connect(owner).transfer(alice.address, ethers.parseEther('100'));
    await erc20.connect(owner).transfer(bob.address, ethers.parseEther('100'));
    await erc20.connect(owner).transfer(charlie.address, ethers.parseEther('100'));
    await erc20.connect(owner).transfer(frank.address, ethers.parseEther('100'));
    await erc20.connect(owner).transfer(buyer.address, ethers.parseEther('100'));

    return {
        owner, 
        alice, 
        bob, 
        charlie, 
        david, 
        eve,
        frank,
        buyer,
        commissionReceiver,

        ReleaseManagerFactoryF,
        ReleaseManagerF,
        NFTFactoryF,
        NFTF,
        NFTStateF,
        NFTViewF,
        //CostManagerFactory,
        ERC20F,
        //BuyerF,
        // NFTSalesF,
        // NFTSalesFactoryF,
        // HookF,
        // BadHookF,
        // FalseHookF,
        // NotSupportingHookF,
        // WithoutFunctionHookF,
        // MockCommunityF,
        AuctionFactoryF,
        AuctionF,
        AuctionCommunityF,
        AuctionNFTF,
        AuctionSubscriptionF,


        TOTALSUPPLY,
        ZERO_ADDRESS,
        NO_COSTMANAGER,
        DEAD_ADDRESS,
        contractURI,
        SERIES_BITS,

        nftState,
        nftView,
        nftImpl,
        
        AuctionImpl,
        AuctionCommunityImpl,
        AuctionNFTImpl,
        AuctionSubscriptionImpl,
        
        releaseManager,

        
        //costManager,
        mockUsefulContract,
        erc20,
        // costManagerGood,
        // costManagerBad,
        // nftsale_implementation,
        // nftSaleFactory,
        // badNFTSale,
        // hook1,
        // hook2,
        // hook3,
        // badHook,
        // falseHook,
        // notSupportingHook,
        // withoutFunctionHook,
        // mockCommunity
    }
}

async function deployFactories () {
    const res = await loadFixture(deployBase);
    const {
        owner,
        NFTFactoryF,
        nftImpl, 
        nftState, 
        nftView,
        //---
        AuctionFactoryF,
        AuctionImpl,
        AuctionCommunityImpl,
        AuctionNFTImpl,
        AuctionSubscriptionImpl,

        ZERO_ADDRESS, 
        NO_COSTMANAGER,
        releaseManager
    } = res;

    const nftFactory = await NFTFactoryF.deploy(nftImpl.target, nftState.target, nftView.target, ZERO_ADDRESS, releaseManager.target);
    const auctionFactory = await AuctionFactoryF.connect(owner).deploy(
        AuctionImpl.target, 
        AuctionNFTImpl.target, 
        AuctionCommunityImpl.target, 
        AuctionSubscriptionImpl.target, 
        NO_COSTMANAGER, 
        releaseManager.target
    );
    // 
    const factoriesList = [nftFactory.target, auctionFactory.target];
    const factoryInfo = [
        [
            2,//uint8 factoryIndex; 
            2,//uint16 releaseTag; 
            "0x53696c766572000000000000000000000000000000000000"//bytes24 factoryChangeNotes;
        ],
        [
            1,//uint8 factoryIndex; 
            1,//uint16 releaseTag; 
            "0x53696c766572000000000000000000000000000000000000"//bytes24 factoryChangeNotes;
        ]
    ]
        
    await releaseManager.connect(owner).newRelease(factoriesList, factoryInfo);

    return {
        ...res,
        ...{
            nftFactory,
            auctionFactory
        }
    }
}

async function deploy() {
    const res = await loadFixture(deployFactories);
    const {
        owner,
        alice,
        commissionReceiver,
        bob,

        ZERO_ADDRESS,
        
        NFTF,
        //BuyerF,
        nftFactory,
    } = res;

    //const seriesId = 1000n;
    const seriesId = BigInt(0x1000000000);
    const tokenId = 1n;
    const id = seriesId * (2n ** 192n) + (tokenId);
    const price = ethers.parseEther('1');
    const autoincrementPrice = 0n;
    const now = BigInt(Math.round(Date.now() / 1000));   
    const baseURI = "http://baseUri/";
    const suffix = ".json";
    const limit = 10000n;
    const saleParams = [
        now + 100000n, 
        ZERO_ADDRESS, 
        price,
        autoincrementPrice
    ];
    const commissions = [
        0n,
        ZERO_ADDRESS
    ];
    const seriesParams = [
        alice.address,  
        10000n,
        saleParams,
        commissions,
        baseURI,
        suffix
    ];

    /////////////////////////////////
    //--b
    const name = "NFT Edition";
    const symbol = "NFT";
    let tx,rc,event,instance;
    tx = await nftFactory.connect(owner)["produce(string,string,string)"](name, symbol, "");
    rc = await tx.wait();
    event = rc.logs.find(event => event.fragment && event.fragment.name === 'InstanceCreated');
    var [/*name*/, /*symbol*/, instanceAddr, /*instancesCount*/] = event.args;
    //let instanceAddr = rc['events'][0].args.instance;

    const nft = await NFTF.attach(instanceAddr);
    //--e

    await nft.connect(owner)["setSeriesInfo(uint64,(address,uint32,(uint64,address,uint256,uint256),(uint64,address),string,string))"](seriesId, seriesParams);
    const retval = '0x150b7a02';
    const error = 0n;
    //const buyerContract = await BuyerF.deploy(retval, error);

    const FRACTION = 10000n;
    const TEN_PERCENTS = 10n * (FRACTION) / (100n);//BigNumber.from('10000');
    const FIVE_PERCENTS = 5n * (FRACTION) / (100n);//BigNumber.from('5000');
    const ONE_PERCENT = 1n * (FRACTION) / (100n);//BigNumber.from('1000');
    const seriesCommissions = [
        TEN_PERCENTS,
        alice.address
    ];
    const maxValue = TEN_PERCENTS;
    const minValue = ONE_PERCENT;
    const defaultCommissionInfo = [
        maxValue,
        minValue,
        [
            FIVE_PERCENTS,
            commissionReceiver.address
        ]
    ];

    return {
        ...res,
        ...{
            seriesId,
            tokenId,
            id,
            price,
            autoincrementPrice,
            now,
            baseURI,
            suffix,
            limit,
            saleParams,
            commissions,
            seriesParams,
            name,
            symbol,

            FRACTION,
            TEN_PERCENTS,
            FIVE_PERCENTS,
            ONE_PERCENT,
            seriesCommissions,
            maxValue,
            minValue,
            defaultCommissionInfo,


            nft,
            //buyerContract,
        }
    };

}

module.exports = {
    deployBase,
    deployFactories,
    deploy,
}