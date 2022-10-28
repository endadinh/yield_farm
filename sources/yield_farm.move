module YieldFarmDeployer::Coin98YieldFarm { 
    use std::signer;
    use std::string::utf8;
    use std::type_info::{Self, TypeInfo};
    use std::event;
    use std::vector;
    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};

    // Constant Variable

    /// When user is not admin.
    const ERR_FORBIDDEN: u64 = 103;
    /// When Coin not registerd by admin.
    const ERR_LPCOIN_NOT_EXIST: u64 = 104;
    /// When Coin already registerd by admin.
    const ERR_LPCOIN_ALREADY_EXIST: u64 = 105;
    /// When not enough amount.
    const ERR_INSUFFICIENT_AMOUNT: u64 = 106;
    /// When need waiting for more blocks.
    const ERR_WAIT_FOR_NEW_BLOCK: u64 = 107;

    const ACC_C98_PRECISION: u128 = 1000000000000;  // 1e12
    const DEPLOYER: address = @YieldFarmDeployer;

    const RESOURCE_ACCOUNT_ADDRESS: address = @YieldFarmResourceAccount;   // gas saving
   
    // C98 Coin

    struct C98 {}

    struct Caps has key { 
        direct_mint: bool,
        mint: MintCapability<C98>, 
        freeze: FreezeCapability<C98>,
        burn: BurnCapability<C98>,
    }

    /** 
    * C98 mint & burn
    */

    public entry fun mint_C98(
        admin: &signer,
        amount: u64,
        to: address
    ) acquires YieldFarmData, Caps { 
        let yf_data = borrow_global_mut<YieldFarmData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == yf_data.admin_address,ERR_FORBIDDEN);
        let caps = borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS);
        let direct_mint = caps.direct_mint;
        assert!(direct_mint == true, ERR_FORBIDDEN);
        let coins = coin::mint<C98>(amount, &caps.mint);
        coin::deposit(to,coins);
    }

    public entry fun burn_C98(
        account: &signer,
        amount: u64
    ) acquires Caps { 
        let coin_b = &borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS).burn;
        let coins = coin::withdraw<C98>(account,amount);
        coin::burn(coins,coin_b);
    }

    //events 
    struct Events<phantom X> has key { 
        add_event: event::EventHandle<CoinMeta<X>>,
        set_event: event::EventHandle<CoinMeta<X>>,
        deposit_event: event::EventHandle<DepositWithdrawEvent<X>>,
        withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
        emergency_withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
    }

    // Add/set event data
    struct CoinMeta<phantom X> has drop, store, copy { 
        alloc_point: u64,
    }

    // Deposit / Withdraw event data
    struct DepositWithdrawEvent<phantom X> has drop, store { 
        amount: u64,
        amount_C98: u64,
    }

    // info of each user, store at user's address
    struct UserInfo<phantom X> has key,store,copy { 
        amount: u64,            // `amount` LP coin amount the user has provided.
        reward_debt: u128,      // Reward debt. See explanation below.
    }

    // info of each pool, store at deployer's address
    struct PoolInfo<phantom X> has key, store { 
        acc_C98_per_share: u128,            // times ACC_C98_PRECISION
        last_reward_timestamp: u64,
        alloc_point: u64,
    }

    // All added lp 
    struct LPInfo has key { 
        lp_list: vector<TypeInfo>,
    }

    // Resource account signer
    // fun get_resource_account(): signer acquires YieldFarmData {}

     struct YieldFarmData has drop, key {
        signer_cap: SignerCapability,
        total_alloc_point: u64,
        admin_address: address,
        dao_address: address,   // dao fee to address
        dao_percent: u64,   // dao fee percent
        bonus_multiplier: u64,  // Bonus muliplier for early C98 makers.
        last_timestamp_dao_withdraw: u64,  // Last timestamp then develeper withdraw dao fee
        start_timestamp: u64,   // mc mint C98 start from this ts
        per_second_C98: u128, // default C98 per second, 1 C98/second = 86400 C98/day, remember times bonus_multiplier
    }

}