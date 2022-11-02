import { AptosAccount, AptosClient, CoinClient, FaucetClient, TokenClient, HexString } from "aptos"

const NODE_URL = "https://fullnode.devnet.aptoslabs.com"
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com"

class HelloAptosClient extends AptosClient {
    constructor() {
        super(NODE_URL)
    }

    async initialize_coin_c98_usdt(adminAccount: AptosAccount) : Promise<string> { 
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::initialize",
            type_arguments: [],
            arguments: []
        })
        const bscTx = await this.signTransaction(adminAccount, rawTx)
        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    } 

    async register_coins_all(account: AptosAccount) : Promise<string> { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::register_coins_all",
            type_arguments: [],
            arguments: []
        })
        const bscTx = await this.signTransaction(account, rawTx)
        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }
    async mint_coin(adminAccount: AptosAccount, receiver: HexString, amount: number) : Promise<string> { 
        const rawTx = await this.generateTransaction(adminAccount.address(), { 
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::mint_coin",
            type_arguments: ["0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::C98"],
            arguments:[receiver,amount]
        })

        const mintTx = await this.signTransaction(adminAccount,rawTx)
        const pendingTx = await this.submitTransaction(mintTx);
        return pendingTx.hash
    }

    async initialize(adminAccount: AptosAccount): Promise<string> {
        const rawTx = await this.generateTransaction(adminAccount.address(), {
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::Coin98MasterChef::initialize",
            type_arguments: [],
            arguments: []
        })

        const bscTx = await this.signTransaction(adminAccount, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async add(account: AptosAccount, alloc_point: number) { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::Coin98MasterChef::add",
            type_arguments: ["0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::C98"],
            arguments: [alloc_point]
        })

        const bscTx = await this.signTransaction(account, rawTx)

        const pendingTx = await this.submitTransaction(bscTx)
        return pendingTx.hash
    }

    async deposit(account: AptosAccount, amount_in: number) { 
        const rawTx = await this.generateTransaction(account.address(), {
            function: "0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::Coin98MasterChef::deposit",
            type_arguments: ["0xa6c171630a309ef0d61c294addb2ad263aad5fa570778edfd53c5efd36e53a50::c98_coin::C98"],
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
        let privateKeyBytes_alice = new TextEncoder().encode("0x6eecd9aa300dc5bb0ac11d14a3879907c6dc11dc1b61edea7fa7f8eb409feb46")
        let privateKeyBytes_bob = new TextEncoder().encode("0x4713866366c0de30a60c8cd74df33edcd276db92f064655f629e22ea6871e7d3")
        // let privateKeyBytes_c98 = new TextEncoder().encode("0x4713866366c0de30a60c8cd74df33edcd276db92f064655f629e22ea6871e7d3")
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
        console.log("");


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

    // it("Initialize C98 - USDT, Register_coins_all" , async () => { 
    //     const txHash = await client.initialize_coin_c98_usdt(bobAccount);
    //     await client.waitForTransaction(txHash, {checkSuccess: true});
    //     console.log('Initialize C98 - USDT - Register coins Success, Hash : ', txHash);
    // })

    it("Register_coins_all" , async () => { 
        const txHash = await client.register_coins_all(bobAccount);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('Register coins Success, Hash : ', txHash);
    })

    it("Mint coin", async () => { 
        const txHash = await client.mint_coin(aliceAccount,bobAccount.address(),100_000_000);
        await client.waitForTransaction(txHash, {checkSuccess: true});
        console.log('mint coin tx', txHash);
    })
    // it("Register coin", async () => { 
    //     const txHash = await client.registerCoin(aliceAccount.address(), bobAccount)
    //     await client.waitForTransaction(txHash, { checkSuccess: true })
    //     console.log("Transaction success", txHash)
    // })

    // it("Create collection", async () => {
    //     const txnHash1 = await tokenClient.createCollection(
    //         aliceAccount,
    //         collectionName,
    //         "Alice's simple collection",
    //         "https://alice.com",
    //     ); // <:!:section_4
    //     await client.waitForTransaction(txnHash1, { checkSuccess: true });
    //     console.log('txHash ne', txnHash1)
    // })

    // it("Create a token in that collection.", async () => {
    //     // :!:>section_5
    //     const txnHash2 = await tokenClient.createToken(
    //         aliceAccount,
    //         collectionName,
    //         tokenName,
    //         "Alice's simple token",
    //         1,
    //         "https://aptos.dev/img/nyan.jpeg",
    //     ); // <:!:section_5
    //     await client.waitForTransaction(txnHash2, { checkSuccess: true });

    //     // Print the collection data.
    //     // :!:>section_6
    //     const collectionData = await tokenClient.getCollectionData(aliceAccount.address(), collectionName);
    //     console.log('txHash here : ', txnHash2);
    //     console.log(`Alice's collection: ${JSON.stringify(collectionData, null, 4)}`); // <:!:section_6

    // })

    it("Initialize", async () => {
        const txHash = await client.initialize(aliceAccount)
        await client.waitForTransaction(txHash, { checkSuccess: true })
        console.log("Transaction success", txHash)
    })

    // it("add",async () => { 
    //     const txHash = await client.add(aliceAccount,1);
    //     await client.waitForTransaction(txHash,{checkSuccess: true})
    //     console.log("add hash ", txHash);
    // })

    it("deposit", async () => { 
        const txHash = await client.deposit(bobAccount,100_000_000);
        await client.waitForTransaction(txHash,{checkSuccess: true})
        console.log("add hash ", txHash);
    })

    it("balance after deposit", async() => { 

    })
})