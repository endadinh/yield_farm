module MasterChefDeployer::Coin98MasterChef { 
    use std::event;
    use std::signer;
    use std::vector;
    use std::string::utf8;
    use aptos_std::math64;
    use aptos_framework::timestamp;
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::account::{Self};
    use aptos_framework::coin::{Self,Coin};

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
    /// When not exist pool on account
    const ERR_POOL_NOT_EXIST: u64 = 110;
    /// WHEN input : u64 not greater than zero
    const ERR_MUST_BE_GREATER_THAN_ZERO: u64 = 111;
    /// When initialized masterchef
    const ERR_INITIALIZED : u64  = 112;
    /// SarosFarmAptos: Time overlap.
    const ERR_TIME_OVERLAP: u64 = 113;

    const ACC_POINT_PRECISION_E12: u128 = 1000000000000;  // 1e12

    const ACC_POINT_PRECISION_E9: u128 = 1000000000;  // 1e12


    const DEPLOYER_ADDRESS: address = @MasterChefDeployer;

    const RESOURCE_ACCOUNT_ADDRESS: address = @ResourceAccountDeployer;   // gas saving

    //events 
    struct Events<phantom X> has key { 
        add_event: event::EventHandle<CoinMeta<X>>,
        set_event: event::EventHandle<CoinMeta<X>>,
        deposit_event: event::EventHandle<DepositWithdrawEvent<X>>,
        withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
        emergency_withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
    }

    struct AdminData has drop, store, copy {
        admin_address: address,
        is_pause: bool, // pause admin
    }

    struct AdminInfo has key { 
        admin_list: vector<AdminData>
    }

    // Deposit / Withdraw event data
    struct DepositWithdrawEvent<phantom X> has drop, store { 
        amount_lp: u64,
        amount_C98: u64,
    }
    
    // Add/set event data
    struct CoinMeta<phantom X> has drop, store, copy { 
        type_info: TypeInfo,
        alloc_point: u64,
    }

    // info of each user, store at user's address
    struct UserInfo<phantom X> has key,store,copy { 
        amount: u64,            // `amount` LP coin amount the user has provided.
        total_staked: u64,      // Reward debt. See explanation below.
    }

    struct UserRewardInfo<phantom X> has key, store, copy { 
        amount: u64,
        reward_debt: u64,
        reward_pending: u64
    }

    // info of each pool, store at deployer's address
    struct PoolInfo<phantom X> has key, store { 
        lp_token: Coin<X>,
        is_pause: bool,
    }

     struct PoolRewardInfoTest<phantom X,phantom Y> has key, store { 
        reward_token: Coin<Y>,
        reward_per_block: u128, // decimals: 3
        reward_end_block: u64,
        total_shares: u64,
        accumulated_reward_per_share: u128, // decimals: 12
        last_updated_block: u64,
        total_claimed: u64,
        is_pause: bool
    }

    // Initialization
    // only AdminInfo issuer can initialize
    public entry fun initialize(account: &signer) {
        let owner = signer::address_of(account);
        assert!(owner == RESOURCE_ACCOUNT_ADDRESS, ERR_FORBIDDEN);
        move_to(account, AdminInfo {
            admin_list: vector::empty(),
        });
    }


    public entry fun set_admin(owner: &signer, admin: address) acquires AdminInfo { 
        let owner_addr = signer::address_of(owner);
        let check_admin = is_admin(admin);

        assert!(!check_admin, ERR_FORBIDDEN);
        // assert!(owner_addr == RESOURCE_ACCOUNT_ADDRESS, ERR_FORBIDDEN);
        let admin_data = get_admin_data(admin);
        let admin_info = borrow_global_mut<AdminInfo>(RESOURCE_ACCOUNT_ADDRESS);
        vector::push_back<AdminData>(&mut admin_info.admin_list, copy admin_data);
    } 

    public entry fun create_pool_reward_test<Pool, RewardToken>(admin: &signer,reward_per_block: u128, reward_start_block: u64 , reward_end_block: u64, is_pause: bool) acquires PoolRewardInfoTest { 
        let admin_addr = signer::address_of(admin);
        let current_block = timestamp::now_seconds();
        // let admin_data = borrow_global_mut<AdminData>(admin_addr);
        assert!(!exists<PoolRewardInfoTest<Pool,RewardToken>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_ALREADY_EXIST);
        assert!(!(reward_start_block >= reward_end_block),ERR_TIME_OVERLAP);
        
        move_to(admin, PoolRewardInfoTest<Pool,RewardToken> { 
            reward_token: coin::zero<RewardToken>(),
            reward_per_block: reward_per_block,
            reward_end_block: current_block + reward_end_block,
            total_shares: 0,
            accumulated_reward_per_share: 0,
            last_updated_block: current_block + reward_start_block,
            total_claimed: 0,
            is_pause: is_pause
        });

        let amount_need_deposit = calculate_amount_need_deposit<Pool,RewardToken>(admin);
        let coins_in = coin::withdraw<RewardToken>(admin, amount_need_deposit);
        let _amount_in = coin::value(&coins_in);
        let pool_reward_info = borrow_global_mut<PoolRewardInfoTest<Pool,RewardToken>>(RESOURCE_ACCOUNT_ADDRESS);
        coin::merge(&mut pool_reward_info.reward_token, coins_in);

    }

    struct PoolRewardInfo<phantom X> has key, store { 
        reward_token: Coin<X>,
        reward_per_block: u128, // decimals: 3
        reward_end_block: u64,
        total_shares: u64,
        accumulated_reward_per_share: u128, // decimals: 12
        last_updated_block: u64,
        total_claimed: u64,
        is_pause: bool
    }

    // Store staked LP info under account resource
    struct LPInfo has key { 
        lp_list: vector<TypeInfo>,
    }

    public entry fun create_pool<X>(admin: &signer, is_pause: bool) { 
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(!exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_ALREADY_EXIST);
        move_to(admin, PoolInfo<X>{ 
            lp_token : coin::zero<X>(),
            is_pause: is_pause,
        });

    }
    // public entry fun create_pool_reward<X>(admin: &signer, reward_per_block: u128, reward_start_block: u64 , reward_end_block: u64, is_pause: bool)  acquires PoolRewardInfo { 
    //     let admin_addr = signer::address_of(admin);
    //     let current_block = timestamp::now_seconds();
        
    //     assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
    //     assert!(!exists<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_ALREADY_EXIST);
    //     assert!(!(reward_start_block >= reward_end_block),ERR_TIME_OVERLAP);
        
    //     move_to(admin, PoolRewardInfo<X> { 
    //         reward_token: coin::zero<X>(),
    //         reward_per_block: reward_per_block,
    //         reward_end_block: current_block + reward_end_block,
    //         total_shares: 0,
    //         accumulated_reward_per_share: 0,
    //         last_updated_block: current_block + reward_start_block,
    //         total_claimed: 0,
    //         is_pause: is_pause
    //     });

    //     let amount_need_deposit = calculate_amount_need_deposit<X>(admin);
    //     let coins_in = coin::withdraw<X>(admin, amount_need_deposit);
    //     let _amount_in = coin::value(&coins_in);
    //     let pool_reward_info = borrow_global_mut<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
    //     coin::merge(&mut pool_reward_info.reward_token, coins_in);

    // }

    public entry fun set_pause_pool<X>(admin: &signer, is_pause: bool) acquires PoolInfo { 
        let admin_addr = signer::address_of(admin);
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);

        let pool_info = borrow_global_mut<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        pool_info.is_pause = is_pause;
    }

    public entry fun set_pause_pool_reward<X>(admin: &signer, is_pause: bool) acquires PoolRewardInfo { 
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(exists<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);

        let pool_info = borrow_global_mut<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        pool_info.is_pause = is_pause;
    }

    public entry fun stake_pool<X>(account: &signer,amount: u64) acquires PoolInfo, UserInfo { 

        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);
        let pool_info = borrow_global_mut<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        let coins_in = coin::withdraw<X>(account, amount);
        let _amount_in = coin::value(&coins_in);

        assert!(_amount_in > 0, ERR_MUST_BE_GREATER_THAN_ZERO);

        coin::merge(&mut pool_info.lp_token, coins_in);

        let user_addr = signer::address_of(account);
        if(!exists<UserInfo<X>>(user_addr)) { 
            move_to(account, UserInfo<X> { 
                amount: _amount_in,
                total_staked: 0,
            })
        } else { 
            let existing_info = borrow_global_mut<UserInfo<X>>(user_addr);
            existing_info.amount = existing_info.amount + _amount_in;
        }

    }

    public entry fun stake_pool_reward<X>(account: &signer) { 
        let user_addr = signer::address_of(account);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);
        assert!(exists<UserInfo<X>>(user_addr), ERR_USERINFO_NOT_EXIST); 
    }





    /////////////////////////////////// UPDATE POOL Func //////////////////////////////////////
    
    /// Calculate amount need deposit

    // public entry fun calculate_amount_need_deposit<X>(admin: &signer) : u64 acquires PoolRewardInfo{
    //     let admin_addr = signer::address_of(admin);

    //     assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
    //     assert!(exists<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);
        
    //     let pool_reward_info = borrow_global_mut<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);

    //     let past_reward = (pool_reward_info.total_shares as u128) * (pool_reward_info.accumulated_reward_per_share);
    //     let pending_reward_blocks = ( pool_reward_info.reward_end_block as u128)  - ( pool_reward_info.last_updated_block as u128) ;
    //     let pending_reward = pending_reward_blocks * pool_reward_info.reward_per_block * ACC_POINT_PRECISION_E9;
    //     let total = (past_reward + pending_reward) / ACC_POINT_PRECISION_E12;
    //     (total as u64)
    // } 
    
     public entry fun calculate_amount_need_deposit<Pool,RewardToken>(admin: &signer) : u64 acquires PoolRewardInfoTest{
        let admin_addr = signer::address_of(admin);

        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(exists<PoolRewardInfoTest<Pool,RewardToken>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);
        
        let pool_reward_info = borrow_global_mut<PoolRewardInfoTest<Pool,RewardToken>>(RESOURCE_ACCOUNT_ADDRESS);

        let past_reward = (pool_reward_info.total_shares as u128) * (pool_reward_info.accumulated_reward_per_share);
        let pending_reward_blocks = ( pool_reward_info.reward_end_block as u128)  - ( pool_reward_info.last_updated_block as u128) ;
        let pending_reward = pending_reward_blocks * pool_reward_info.reward_per_block * ACC_POINT_PRECISION_E9;
        let total = (past_reward + pending_reward) / ACC_POINT_PRECISION_E12;
        (total as u64)
    } 

    public entry fun update_pool_reward<X>(admin: &signer) acquires PoolRewardInfo { 
        let admin_addr = signer::address_of(admin);

        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(exists<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);

        let pool_reward_info = borrow_global_mut<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        
        if (!pool_reward_info.is_pause) { 
            return
        };

        let current_block = timestamp::now_seconds();
        let reward_at_block = math64::min(current_block, pool_reward_info.reward_end_block);

        if ( reward_at_block <= pool_reward_info.last_updated_block) { 
            return
        };

        let pending_reward_blocks = ((reward_at_block - pool_reward_info.last_updated_block) as u128);
        let pending_reward = pending_reward_blocks * pool_reward_info.reward_per_block * ACC_POINT_PRECISION_E9;
        let pending_reward_per_share = pending_reward / (pool_reward_info.total_shares as u128);

        pool_reward_info.accumulated_reward_per_share = pool_reward_info.accumulated_reward_per_share + pending_reward_per_share;
        pool_reward_info.last_updated_block = reward_at_block;
    }    

    public entry fun calculate_reward<X>(admin: &signer,amount: u64, reward_debt: u64, reward_pending: u64) : u64 acquires PoolRewardInfo { 
        let admin_addr = signer::address_of(admin);

        assert!(admin_addr == RESOURCE_ACCOUNT_ADDRESS,ERR_FORBIDDEN);
        assert!(exists<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);

        let pool_reward_info = borrow_global_mut<PoolRewardInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);

        let sub_total = (amount as u128) * pool_reward_info.accumulated_reward_per_share /  ACC_POINT_PRECISION_E12;
        let total = sub_total + (reward_pending as u128) - (reward_debt as u128);

        (total as u64)
    }

    public entry fun create_user_pool<X>(user : &signer, pool_key : address) { 
        
    }


    public fun get_admin_data(admin_addr: address): AdminData {
        AdminData {
            admin_address: admin_addr,
            is_pause: false
        }
    }

    public entry fun is_admin(admin_addr: address): bool acquires AdminInfo {
        let admin_info = borrow_global<AdminInfo>(RESOURCE_ACCOUNT_ADDRESS);
        let i = 0;
        let len = vector::length<AdminData>(&admin_info.admin_list);
        while (i < len) {
            let admin_data = vector::borrow<AdminData>(&admin_info.admin_list, i);
            if (admin_data.admin_address == admin_addr) return true
        };
        return false
    }


    // public entry fun initialize(admin: &signer) { 
    //     let admin_addr = signer::address_of(admin);
    //     let current_timestamp = timestamp::now_seconds();
    //     assert!(!exists<MasterChefData>(admin_addr), ERR_INITIALIZED);
    //     move_to(admin, MasterChefData { 
    //         total_alloc_point: 0,
    //         admin_address: admin_addr,
    //         dev_address: admin_addr,
    //         dev_percent: 1,
    //         bonus_multiplier: 1,
    //         last_timestamp_dev_withdraw: current_timestamp,
    //         start_timestamp: current_timestamp,
    //         per_second_reward: 100,
    //     })

    // }

    /// Getting info function's list ///
    /// Get user deposit amount
    // public entry fun get_user_info_amount<X,Y>(user_addr: address) : u64 acquires UserInfo { 
    //     assert!(exists<UserInfo<X,Y>>(user_addr), ERR_USERINFO_NOT_EXIST);
    //     let user_info = borrow_global<UserInfo<X,Y>>(user_addr);
    //     user_info.amount
    // }

    /// Get the pending reward token amount
    // public fun get_pending_rewardtoken(account: address): u64 {}
    
/// Only owner function's list ///
    
    /// Setting capabilities for reward token under user account



    // public entry fun setting_reward_token<CoinType>(admin: &signer) { 
    //     let reward_token_data = borrow_global_mut<RewardToken>;
    //     let admin_addr = signer::address_of(account);
    //     // assert!(admin_addr == reward_token_data.admin_address, ERR_FORBIDDEN);

    //     let old_reward_token = reward_token_data.reward_token;
    //     let balance = reward_token_data.reward_token.value;
    //     let coins_out = coin::extract(&mut reward_token_data.reward_token, balance);
    //     coin::deposit<old_reward_token>(admin_addr,coins_out);

    //     reward_token_data.reward_token = coin::zero<CoinType>();


    // }

//     /// set admin address  
//       public entry fun set_admin_address(account: &signer, admin_address: address) acquires MasterChefData {
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
//         masterchef_data.admin_address = admin_address;
//     }

//     /// Set dev address
//     public entry fun set_dev_address(account: &signer, dev_address: address) acquires MasterChefData {
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
//         masterchef_data.dev_address = dev_address;
//     }

//     /// Set dev percent
//     public entry fun set_dev_percent(account: &signer, dev_percent: u64) acquires MasterChefData {
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
//         masterchef_data.dev_percent = dev_percent;
//     }

//     /// Set reward token amount per second
//     public entry fun set_per_second_reward(account: &signer, per_second_reward: u128) acquires MasterChefData {
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
//         masterchef_data.per_second_reward = per_second_reward;
//     }

//     /// Set bonus
//     public entry fun set_bonus_multiplier(account: &signer, bonus_multiplier: u64) acquires MasterChefData {
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(signer::address_of(account) == masterchef_data.admin_address, ERR_FORBIDDEN);
//         masterchef_data.bonus_multiplier = bonus_multiplier;
//     }

//     /// Add a new pool
//     public entry fun add<X,Y>(account: &signer, alloc_point: u64) acquires MasterChefData { 
//         let admin_addr = signer::address_of(account);
//         assert!(exists<MasterChefData>(admin_addr), ERR_FORBIDDEN);
//         let masterchef_data = borrow_global_mut<MasterChefData>(admin_addr);
//         assert!(!exists<PoolInfo<X,Y>>(admin_addr), ERR_POOL_ALREADY_EXIST);
//         let current_timestamp = timestamp::now_seconds();
//         masterchef_data.total_alloc_point =  masterchef_data.total_alloc_point + alloc_point;
//         move_to(account, PoolInfo<X,Y>{ 
//             lp_token : coin::zero<X>(),
//             reward_token: coin::zero<Y>(),
//             alloc_point: alloc_point,
//             acc_reward_per_share: 0,
//             last_reward_timestamp: current_timestamp,
//         })
//     }

//     /// Set the existing pool
    
//     public entry fun set_pool<X,Y>(account: &signer, alloc_point: u64) acquires MasterChefData,PoolInfo { 
//         let admin_addr = signer::address_of(account);
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(masterchef_data.admin_addr == admin_addr, ERR_FORBIDDEN);
//         assert!(exists<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS), ERR_POOL_NOT_EXIST);

//         let existing_pool = borrow_global_mut<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS);
//         masterchef_data.total_alloc_point = masterchef_data.total_alloc_point -  existing_pool.alloc_point + alloc_point;
//         existing_pool.alloc_point = alloc_point;
//     }

// /// functions list for every user ///
//     /// Deposit LP tokens to pool
//     public entry fun deposit<X,Y>(account: &signer, amount_in: u64) acquires UserInfo, PoolInfo, MasterChefData { 
//         let coins_in = coin::withdraw<X>(account, amount_in);
//         let _amount_in = coin::value(&coins_in);
//         assert!(_amount_in > 0, ERR_MUST_BE_GREATER_THAN_ZERO);
        
//         let masterchef_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
//         assert!(exists<PoolInfo<X,Y>>(masterchef_data.admin_address), ERR_POOL_NOT_EXIST);
//         let pool_info = borrow_global_mut<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS);
//         coin::merge(&mut pool_info.lp_token, coins_in);

//         let user_addr = signer::address_of(account);
//         if(!exists<UserInfo<X,Y>>(user_addr)) { 
//             move_to(account, UserInfo<X,Y> { 
//                 amount: _amount_in,
//                 reward_debt: (_amount_in * pool_info.acc_reward_per_share)/ 100,
//             })
//         } else { 
//             let existing_info = borrow_global_mut<UserInfo<X,Y>>(user_addr);
//             existing_info.amount = existing_info.amount + _amount_in;
//         }
//     }
    
//     /// Withdraw LP tokens from pool
//     public entry fun withdraw<X,Y>(account: &signer, amount_out: u64) acquires UserInfo, PoolInfo { 
//         let user_addr = signer::address_of(account);
//         assert!(exists<UserInfo<X,Y>>(user_addr), ERR_USERINFO_NOT_EXIST);

//         let existing_info = borrow_global_mut<UserInfo<X,Y>>(user_addr);
//         assert!(existing_info.amount >= amount_out, ERR_INSUFFICIENT_BALANCE);

//         if(amount_out > 0) { 
//             existing_info.amount = existing_info.amount - amount_out;
//             let pool_info = borrow_global_mut<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS);
//             let coins_out = coin::extract(&mut pool_info.lp_token, amount_out);
//             coin::deposit<X>(user_addr,coins_out);
//         }
//     }

//     public entry fun enter_staking<X,Y>(account: &signer, amount: u64) acquires UserInfo,PoolInfo {
//         let coins_in = coin::withdraw<X>(account, amount);
//         let _amount_in = coin::value(&coins_in);
//         assert!(_amount_in > 0, ERR_MUST_BE_GREATER_THAN_ZERO);


//         let pool_info = borrow_global_mut<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS);
//         coin::merge(&mut pool_info.lp_token, coins_in);

//         let user_addr = signer::address_of(account);
//         if(!exists<UserInfo<X,Y>>(user_addr)) { 
//             move_to(account, UserInfo<X,Y> { 
//                 amount: _amount_in,
//                 reward_debt: (_amount_in * pool_info.acc_reward_per_share)/ 100,
//             })
//         } else { 
//             let existing_info = borrow_global_mut<UserInfo<X,Y>>(user_addr);
//             existing_info.amount = existing_info.amount + _amount_in;
//         }
//     }
//     // public entry fun leave_staking(account: &signer, amount: u64) {}

//     // Withdraw without caring about the rewards. EMERGENCY ONLY
//     public entry fun emergency_withdraw<X,Y>(account: &signer) acquires UserInfo,PoolInfo { 
//         let user_addr = signer::address_of(account);
//         assert!(exists<UserInfo<X,Y>>(user_addr), ERR_USERINFO_NOT_EXIST);
        
//         let existing_info = borrow_global_mut<UserInfo<X,Y>>(user_addr);
//         let amount_out = existing_info.amount;
//         assert!(amount_out > 0, ERR_MUST_BE_GREATER_THAN_ZERO);

//         existing_info.amount = 0;
//         let pool_info = borrow_global_mut<PoolInfo<X,Y>>(RESOURCE_ACCOUNT_ADDRESS);
//         let coins_out = coin::extract(&mut pool_info.lp_token, amount_out);
//         coin::deposit<X>(user_addr, coins_out);
//     }

}