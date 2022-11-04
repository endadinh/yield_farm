import { AptosAccount, AptosClient, CoinClient, FaucetClient, TokenClient, HexString } from "aptos"

const NODE_URL = "https://fullnode.devnet.aptoslabs.com"
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com"

const C98_Token = "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::c98_coin::C98";
const USDT_Token  = "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::c98_coin::USDT";

class HelloAptosClient extends AptosClient {
    constructor() {
        super(NODE_URL)
    }

    async initialize_coin_c98_usdt(adminAccount: AptosAccount) : Promise<string> { 
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::c98_coin::initialize",
            type_arguments: [],
            arguments: []
        })
        const bscTx = await this.signTransaction(adminAccount, rawTx)
        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    } 

    async register_coins_all(account: AptosAccount) : Promise<string> { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::c98_coin::register_coins_all",
            type_arguments: [],
            arguments: []
        })
        const bscTx = await this.signTransaction(account, rawTx)
        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async mint_coin(adminAccount: AptosAccount, coinType: string, receiver: HexString, amount: number) : Promise<string> { 
        const rawTx = await this.generateTransaction(adminAccount.address(), { 
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::c98_coin::mint_coin",
            type_arguments: [coinType],
            arguments:[receiver,amount]
        })

        const mintTx = await this.signTransaction(adminAccount,rawTx)
        const pendingTx = await this.submitTransaction(mintTx);
        return pendingTx.hash
    }

    async initialize(adminAccount: AptosAccount): Promise<string> {
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::initialize",
            type_arguments: [],
            arguments: []
        })

        const bscTx = await this.signTransaction(adminAccount, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async set_admin(adminAccount: AptosAccount, admin: HexString): Promise<string> {
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::set_admin",
            type_arguments: [],
            arguments: [admin]
        })

        const bscTx = await this.signTransaction(adminAccount, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async get_ticket_info(adminAccount: AptosAccount, address: HexString): Promise<string> {
        this.estimateMaxGasAmount(adminAccount.address());
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::is_admin",
            type_arguments: [],
            arguments: [address]
        })

        const bscTx = await this.signTransaction(adminAccount, rawTx)

        const pendingTx = await this.submitTransaction(bscTx);
        console.log('pendingTx,',pendingTx)
        return pendingTx.hash
    }

    async create_pool(account: AptosAccount, CoinType: string, is_pause: boolean) { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::create_pool",
            type_arguments: [CoinType],
            arguments: [is_pause]
        })

        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async create_reward_pool(account: AptosAccount, CoinType: string, reward_start_block: number, reward_per_block: number, reward_end_block: number, is_pause: boolean) { 
        const rawTx = await this.generateTransaction(account.address(), { 
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::create_pool_reward",
            type_arguments: [CoinType],
            arguments: [reward_per_block,reward_start_block, reward_end_block,is_pause]
        })
        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async calculator(account: AptosAccount, CoinType: string) { 
        const rawTx = await this.generateTransaction(account.address(), { 
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::calculate_amount_need_deposit",
            type_arguments: [CoinType],
            arguments: []
        })
        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async set_pause_pool(account: AptosAccount, coinType: string, pool_type: number , is_pause: boolean) {       /* poolType :  0--pool , 1--reward_pool */ 
        let method = pool_type == 0  ? "set_pause_pool" : "set_pause_pool_reward";
        const rawTx = await this.generateTransaction(account.address(), { 
            function: `0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::${method}`,
            type_arguments: [coinType],
            arguments: [is_pause]
        })

        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    } 

    async deposit(account: AptosAccount,tokenDeposit: string,tokenReward: string, amount_in: number) { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0x975f377c6e13eb08cf462f4dea16f57a48bc82c222af40550928f94f369822af::Coin98MasterChef::deposit",
            type_arguments: [tokenDeposit,tokenReward],
            arguments: [amount_in]
        })

        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }
}

describe("Hello Aptos", () => {
    let client: HelloAptosClient
    let faucetClient: FaucetClient
    let aliceAccount: AptosAccount
    let bobAccount: AptosAccount
    let tokenClient: TokenClient
    let coinClient: CoinClient

    // TOKEN DEFINED
    let collectionName: string
    let tokenName: string
    let tokenPropertyVersion: number
    let tokenId: {}



    before("Create Connection", async () => {
        client = new HelloAptosClient;
        faucetClient = new FaucetClient(NODE_URL, FAUCET_URL)

        // Create client for working with the token module.
        // :!:>section_1b
        tokenClient = new TokenClient(client); // <:!:section_1b

        // Create a coin client for checking account balances.
        coinClient = new CoinClient(client);
        let privateKeyBytes_alice = new TextEncoder().encode("0x3078383834656366393963306664fb2903f18ba93844e011d108b7889e6423b0")

        // Create accounts.
        // :!:>section_2
        aliceAccount = new AptosAccount(privateKeyBytes_alice);
        bobAccount = new AptosAccount(); // <:!:section_2

        const privateKey = await aliceAccount.toPrivateKeyObject();

        // Print out account addresses.
        console.log("=== Addresses ===");
        console.log(`Alice: ${aliceAccount.address()}`);
        console.log(`Alice private key : ${privateKey.privateKeyHex}`)
        console.log(`Bob: ${bobAccount.address()}`);
        // console.log(`Bob private key : ${privateKey.privateKeyHex}`);


        // Fund accounts.
        // :!:>section_3
        await faucetClient.fundAccount(aliceAccount.address(), 100_000_000);
        await faucetClient.fundAccount(bobAccount.address(), 100_000_000); // <:!:section_3

        console.log("=== Initial Coin Balances ===");
        console.log(`Alice: ${await coinClient.checkBalance(aliceAccount)}`);
        console.log(`Bob: ${await coinClient.checkBalance(bobAccount)}`);
        console.log("");

        console.log("=== Creating Collection and Token ===");

        collectionName = "Alice's";
        tokenName = "Alice's first token";
        tokenPropertyVersion = 0;

        tokenId = {
            token_data_id: {
                creator: aliceAccount.address().hex(),
                collection: collectionName,
                name: tokenName,
            },
            property_version: `${tokenPropertyVersion}`,
        };



    })

    it("Initialize C98 - USDT, Run 1 times" , async () => { 
        const txHash = await client.initialize_coin_c98_usdt(aliceAccount);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('Initialize C98 - USDT - Register coins Success, Hash : ', txHash);
    })

    it("Register_coins_all" , async () => { 
        const txHash = await client.register_coins_all(aliceAccount);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('Register coins Success, Hash : ', txHash);
    })

    it("Mint coin C98", async () => { 
        const txHash = await client.mint_coin(aliceAccount,C98_Token ,aliceAccount.address(),100_000_000);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('mint coin C98 tx', txHash);
    })

    it("Mint coin USDT", async () => { 
        const txHash = await client.mint_coin(aliceAccount, USDT_Token,aliceAccount.address(),100_000_000);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('mint coin USDT tx', txHash);
    })

    // it("Initialize, Run 1 times", async () => {
    //     const txHash = await client.initialize(aliceAccount)
    //     await client.waitForTransaction(txHash, { checkSuccess: true })
    //     console.log("Initialize Masterchef tx", txHash)
    // })

    it("Add pool",async () => { 
        const txHash = await client.create_pool(aliceAccount,USDT_Token,false);
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("Add new pool tx : ", txHash);
    })

    it("Create reward pool", async () => { 
        const txHash = await client.create_reward_pool(aliceAccount,C98_Token,96_000,100_000, 960_000, false);
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("add hash ", txHash);
    })

    it("Set pause pool", async () => { 
        console.log("=============== Pause pool ============");
        const txHash1 = await client.set_pause_pool(aliceAccount,USDT_Token,0,true);
        console.log('hash', txHash1)
        await client.waitForTransaction(txHash1,{checkSuccess: true})
        console.log("=============== unPause pool ============");
        const txHash2 = await client.set_pause_pool(aliceAccount,USDT_Token,0,false);
        console.log('hash', txHash2)
        await client.waitForTransaction(txHash2,{checkSuccess: true})
        console.log("=============== Pause pool reward ============");
        const txHash3 = await client.set_pause_pool(aliceAccount,C98_Token,1,true);
        console.log('hash', txHash3)
        await client.waitForTransaction(txHash3,{checkSuccess: true})
        console.log("=============== unPause pool reward ============");
        const txHash4 = await client.set_pause_pool(aliceAccount,C98_Token,1,false);
        console.log('hash', txHash4)
        await client.waitForTransaction(txHash4,{checkSuccess: true})
    })

    it("Init admin", async () => { 
        const txHash = await client.initialize(aliceAccount);
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("add hash ", txHash);
    })

    it("Set admin", async () => { 
        const txHash = await client.set_admin(aliceAccount,aliceAccount.address());
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("add hash ", txHash);
    })


    it("Get admin", async () => { 
        const txHash = await client.get_ticket_info(aliceAccount,bobAccount.address());
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("add hash ", txHash);
    })

    // it("Create reward pool", async () => { 
    //     const txHash = await client.calculator(aliceAccount,C98_Token);
    //     await client.waitForTransaction(txHash,{checkSuccess: true})
    //     console.log("add hash ", txHash);
    // })

    

    // it("balance after deposit", async() => { 

    // })
})