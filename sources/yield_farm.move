module MasterChefDeployer::Coin98MasterChef { 
    use std::event;
    use std::signer;
    use std::vector;
    use std::string::utf8;
    use aptos_framework::timestamp;
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self,Coin, MintCapability, FreezeCapability, BurnCapability};

    // Constant Variable

    /// When user is not admin.
    const ERR_FORBIDDEN: u64 = 103;
    /// When Coin not registerd by admin.
    const ERR_LPCOIN_NOT_EXIST: u64 = 104;
    /// When Coin already registerd by admin.
    const ERR_LPCOIN_ALREADY_EXIST: u64 = 105;
    /// When not enough balance.
    const ERR_INSUFFICIENT_BALANCE: u64 = 106;
    /// When need waiting for more blocks.
    const ERR_WAIT_FOR_NEW_BLOCK: u64 = 107;
    /// When not exists user info on account
    const ERR_USERINFO_NOT_EXIST: u64 = 108;
    /// When pool ALREADY registerd on account
    const ERR_POOL_ALREADY_EXIST: u64 = 109;
    /// When not exitst pool on account
    const ERR_POOL_NOT_EXIST: u64 = 110;
    /// WHEN input : u64 not greater than zero
    const ERR_MUST_BE_GREATER_THAN_ZERO: u64 = 111;

    const ACC_C98_PRECISION: u128 = 1000000000000;  // 1e12

    const DEPLOYER_ADDRESS: address = @MasterChefDeployer;

    const RESOURCE_ACCOUNT_ADDRESS: address = @ResourceAccountDeployer;   // gas saving
   
    /// Store mint/burn/freeze capabilities for reward token under user account
    /// 
    struct Caps<phantom CoinType> has key {
        direct_mint: bool,
        mint: MintCapability<CoinType>,
        freeze: FreezeCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }


    public entry fun mint_coin<TypeCoin >(
        admin: &signer,
        amount: u64,
        to: address
    ) acquires MasterChefData, Caps { 
        let yf_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == yf_data.admin_address,ERR_FORBIDDEN);
        let caps = borrow_global<Caps<TypeCoin>>(RESOURCE_ACCOUNT_ADDRESS);
        let direct_mint = caps.direct_mint;
        assert!(direct_mint == true, ERR_FORBIDDEN);
        let coins = coin::mint<TypeCoin>(amount, &caps.mint);
        coin::deposit(to,coins);

    }

    public entry fun burn_coin<X>(
        account: &signer,
        amount: u64
    ) acquires Caps { 
        let coin_b = &borrow_global<Caps<X>>(RESOURCE_ACCOUNT_ADDRESS).burn;
        let coins = coin::withdraw<X>(account,amount);
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
        type_info: TypeInfo,
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
        reward_debt: u64,      // Reward debt. See explanation below.
    }

    // info of each pool, store at deployer's address
    struct PoolInfo<phantom CoinType> has key, store { 
        lp_token: Coin<CoinType>,
        alloc_point: u64,
        acc_reward_per_share: u64,           
        last_reward_timestamp: u64,
    }

    // Store staked LP info under masterchef
    struct LPInfo has key { 
        lp_list: vector<TypeInfo>,
    }

    // Resource account signer
    // fun get_resource_account(): signer acquires MasterChefData {}

     struct MasterChefData has drop, key {
        // signer_cap: SignerCapability,
        total_alloc_point: u64,
        admin_address: address,
        dev_address: address,   // dev fee to address
        dev_percent: u64,   // dev fee percent
        bonus_multiplier: u64,  // Bonus muliplier for early token makers.
        per_second_reward: u128, // default reward token per second, 1 token/second = 86400 token/day, remember times bonus_multiplier
        start_timestamp: u64,   // mc mint reward token start from this ts
        last_timestamp_dev_withdraw: u64,  // Last timestamp then develeper withdraw dao fee
    }

    public entry fun initialize<CoinType>(admin: &signer) { 
        let admin_addr = signer::address_of(admin);
        let current_timestamp = timestamp::now_seconds();
        move_to(admin, Caps<CoinType> { 
            direct_mint: true,
            mint: coin<CoinType<MintCapability>>,
            freeze: FreezeCapability<CoinType>,
            burn: BurnCapability<CoinType>
        });

        move_to(admin, MasterChefData { 
            // signer_cap: borrow_global<SignerCapability>(admin),
            total_alloc_point: 0,
            admin_address: admin_addr,
            dev_address: admin_addr,
            dev_percent: 1,
            bonus_multiplier: 1,
            last_timestamp_dev_withdraw: current_timestamp,
            start_timestamp: current_timestamp,
            per_second_reward: 1000,
        })

    }

    //   public entry fun initialize(admin: &signer) {
    //     let admin_addr = signer::address_of(admin);
    //     let current_timestamp = timestamp::now_seconds();
    //     let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
    //         admin,
    //         utf8(b"TestCoin"),
    //         utf8(b"TC"),
    //         10,
    //         true,
    //     );

    //     move_to(admin, Caps<TestCoin>{
    //         direct_mint: true,
    //         mint: mint_cap,
    //         burn: burn_cap,
    //         freeze: freeze_cap,
    //     });
    //     move_to(admin, MasterChefData{
    //         admin_address: admin_addr,
    //         dev_address: admin_addr,
    //         dev_percent: 10,
    //         bonus_multiplier: 10,
    //         total_alloc_point: 0,
    //         per_second_reward: 10000000,
    //         start_timestamp: current_timestamp,
    //         last_timestamp_dev_withdraw: current_timestamp,
    //     });
    // }


/// Getting info function's list ///
    /// Get user deposit amount
    public entry fun get_user_info_amount<CoinType>(user_addr: address): u64 acquires UserInfo { 
        assert!(exists<UserInfo<CoinType>>(user_addr), ERR_USERINFO_NOT_EXIST);
        let user_info = borrow_global<UserInfo<CoinType>>(user_addr);
        user_info.amount
    }

    /// Get the pending reward token amount
    // public fun get_pending_rewardtoken(account: address): u64 {}
    
/// Only owner function's list ///
      public entry fun set_admin_address(account: &signer, admin_address: address) acquires MasterChefData {
        let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
        masterchef_data.admin_address = admin_address;
    }

    /// Set dev address
    public entry fun set_dev_address(account: &signer, dev_address: address) acquires MasterChefData {
        let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
        masterchef_data.dev_address = dev_address;
    }

    /// Set dev percent
    public entry fun set_dev_percent(account: &signer, dev_percent: u64) acquires MasterChefData {
        let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
        masterchef_data.dev_percent = dev_percent;
    }

    /// Set reward token amount per second
    public entry fun set_per_second_reward(account: &signer, per_second_reward: u128) acquires MasterChefData {
        let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
        masterchef_data.per_second_reward = per_second_reward;
    }

    /// Set bonus
    public entry fun set_bonus_multiplier(account: &signer, bonus_multiplier: u64) acquires MasterChefData {
        let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
        masterchef_data.bonus_multiplier = bonus_multiplier;
    }

    /// Add a new pool
    public entry fun add<CoinType>(account: &signer, alloc_point: u64) acquires MasterChefData { 
        let admin_addr = signer::address_of(account);
        let masterchef_data = borrow_global_mut<MasterChefData>(admin_addr);
        
        assert!(!exists<PoolInfo<CoinType>>(admin_addr), ERR_POOL_ALREADY_EXIST);

        let current_timestamp = timestamp::now_seconds();
        masterchef_data.total_alloc_point =  masterchef_data.total_alloc_point + alloc_point;
        move_to(account, PoolInfo<CoinType>{ 
            lp_token : coin::zero<CoinType>(),
            alloc_point: alloc_point,
            acc_reward_per_share: 0,
            last_reward_timestamp: current_timestamp,
        })
    }

    /// Set the existing pool
    
    public entry fun set_pool<CoinType>(account: &signer, alloc_point: u64) acquires MasterChefData,PoolInfo { 
        let admin_addr = signer::address_of(account);
        let masterchef_data = borrow_global_mut<MasterChefData>(admin_addr);

        assert!(exists<PoolInfo<CoinType>>(admin_addr), ERR_POOL_NOT_EXIST);

        let existing_pool = borrow_global_mut<PoolInfo<CoinType>>(admin_addr);
        masterchef_data.total_alloc_point = masterchef_data.total_alloc_point -  existing_pool.alloc_point + alloc_point;
        existing_pool.alloc_point = alloc_point;
    }

/// functions list for every user ///
    /// Deposit LP tokens to pool
    public entry fun deposit<CoinType>(account: &signer, amount_in: u64) acquires UserInfo, PoolInfo { 
        let coins_in = coin::withdraw<CoinType>(account, amount_in);
        let _amount_in = coin::value(&coins_in);
        assert!(_amount_in > 0, ERR_MUST_BE_GREATER_THAN_ZERO);

        let pool_info = borrow_global_mut<PoolInfo<CoinType>>(RESOURCE_ACCOUNT_ADDRESS);
        coin::merge(&mut pool_info.lp_token, coins_in);

        let user_addr = signer::address_of(account);
        if(!exists<UserInfo<CoinType>>(user_addr)) { 
            move_to(account, UserInfo<CoinType> { 
                amount: _amount_in,
                reward_debt: (_amount_in * pool_info.acc_reward_per_share)/ 100,
            })
        } else { 
            let existing_info = borrow_global_mut<UserInfo<CoinType>>(user_addr);
            existing_info.amount = existing_info.amount + _amount_in;
        }
    }
    
    /// Withdraw LP tokens from pool
    public entry fun withdraw<CoinType>(account: &signer, amount_out: u64) acquires UserInfo, PoolInfo { 
        let user_addr = signer::address_of(account);
        assert!(exists<UserInfo<CoinType>>(user_addr), ERR_USERINFO_NOT_EXIST);

        let existing_info = borrow_global_mut<UserInfo<CoinType>>(user_addr);
        assert!(existing_info.amount >= amount_out, ERR_INSUFFICIENT_BALANCE);

        if(amount_out > 0) { 
            existing_info.amount = existing_info.amount - amount_out;
            let pool_info = borrow_global_mut<PoolInfo<CoinType>>(RESOURCE_ACCOUNT_ADDRESS);
            let coins_out = coin::extract(&mut pool_info.lp_token, amount_out);
            coin::deposit<CoinType>(user_addr,coins_out);
        }
    }

    public entry fun enter_staking<CoinType>(account: &signer, amount: u64) acquires UserInfo,PoolInfo {
        let coins_in = coin::withdraw<CoinType>(account, amount);
        let _amount_in = coin::value(&coins_in);
        assert!(_amount_in > 0, ERR_MUST_BE_GREATER_THAN_ZERO);


        let pool_info = borrow_global_mut<PoolInfo<CoinType>>(RESOURCE_ACCOUNT_ADDRESS);
        coin::merge(&mut pool_info.lp_token, coins_in);

        let user_addr = signer::address_of(account);
        if(!exists<UserInfo<CoinType>>(user_addr)) { 
            move_to(account, UserInfo<CoinType> { 
                amount: _amount_in,
                reward_debt: (_amount_in * pool_info.acc_reward_per_share)/ 100,
            })
        } else { 
            let existing_info = borrow_global_mut<UserInfo<CoinType>>(user_addr);
            existing_info.amount = existing_info.amount + _amount_in;
        }
    }
    // public entry fun leave_staking(account: &signer, amount: u64) {}

    // Withdraw without caring about the rewards. EMERGENCY ONLY
    public entry fun emergency_withdraw<CoinType>(account: &signer) acquires UserInfo,PoolInfo { 
        let user_addr = signer::address_of(account);
        assert!(exists<UserInfo<CoinType>>(user_addr), ERR_USERINFO_NOT_EXIST);
        
        let existing_info = borrow_global_mut<UserInfo<CoinType>>(user_addr);
        let amount_out = existing_info.amount;
        assert!(amount_out > 0, ERR_MUST_BE_GREATER_THAN_ZERO);

        existing_info.amount = 0;
        let pool_info = borrow_global_mut<PoolInfo<CoinType>>(RESOURCE_ACCOUNT_ADDRESS);
        let coins_out = coin::extract(&mut pool_info.lp_token, amount_out);
        coin::deposit<CoinType>(user_addr, coins_out);
    }

}