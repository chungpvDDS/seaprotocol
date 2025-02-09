//
// fee denominator is 1000000
module sea::fee {
    use std::signer::address_of;
    use aptos_std::type_info;

    // fee ratio 0.02%
    struct FeeRatio200 has store {}

    // fee ratio 0.05%
    struct FeeRatio500 has store {}

    // fee ratio 0.1%
    struct FeeRatio1000 has store {}

    struct MakerProportion has key {
        grid_proportion: u128,
        order_proportion: u128,
    }

    const PROP_DENOMINATE: u128 = 1000;
    const FEE_DENOMINATE:  u64 = 1000000;

    /// Errors
    const E_NO_FEE_RATIO:  u64 = 4000;
    const E_NO_AUTH:       u64 = 4001;
    const E_INVALID_SHARE: u64 = 4002;

    public entry fun initialize(sea_admin: &signer) {
        assert!(address_of(sea_admin) == @sea, E_NO_AUTH);

        move_to(sea_admin, MakerProportion{
            grid_proportion: 900,
            order_proportion: 400,
            })
    }

    public entry fun modify_maker_port(
        sea_admin: &signer,
        grid: u64,
        order: u64) acquires MakerProportion {
        assert!(address_of(sea_admin) == @sea, E_NO_AUTH);
        assert!(grid <= (PROP_DENOMINATE as u64), E_INVALID_SHARE);
        assert!(order <= (PROP_DENOMINATE as u64), E_INVALID_SHARE);

        let prop = borrow_global_mut<MakerProportion>(@sea);
        prop.grid_proportion = (grid as u128);
        prop.order_proportion = (order as u128);
    }

    // maker fee shares
    // ratio is maker's proportion
    public fun get_maker_fee_shares(
        fee: u64,
        is_grid: bool
    ): (u64, u64) acquires MakerProportion {
        let prop = borrow_global<MakerProportion>(@sea);
        let ratio = if (is_grid) prop.grid_proportion else prop.order_proportion;

        let maker_share = (((fee as u128) * ratio / PROP_DENOMINATE) as u64);
        (maker_share, fee-maker_share)
    }

    /// get fee ratio by type
    public fun get_fee_ratio<F>(): u64 {
        if (type_info::type_of<F>() == type_info::type_of<FeeRatio200>()) {
            return 200
        } else if (type_info::type_of<F>() == type_info::type_of<FeeRatio500>()) {
            return 500
        } else if (type_info::type_of<F>() == type_info::type_of<FeeRatio1000>()) {
            return 1000
        };
    
        assert!(false, E_NO_FEE_RATIO);
        0
    }

    // Tests ==================================================================
    #[test_only]
    use std::vector;
    // #[test_only]
    // use std::debug;

    #[test]
    fun test_get_fee_ratio() {
        let fee200 = get_fee_ratio<FeeRatio200>();
        assert!(fee200 == 200, 200);
        let fee500 = get_fee_ratio<FeeRatio500>();
        assert!(fee500 == 500, 500);
        let fee1000 = get_fee_ratio<FeeRatio1000>();
        assert!(fee1000 == 1000, 1000);
    }

    #[test(sea_admin = @sea)]
    fun test_modify_fee_share(
        sea_admin: &signer
    ) acquires MakerProportion {
        initialize(sea_admin);
        modify_maker_port(sea_admin, 800, 200);
        let prop = borrow_global<MakerProportion>(@sea);
        assert!(prop.grid_proportion == 800, 800);
        assert!(prop.order_proportion == 200, 200);
    }

    #[test(
        sea_admin = @sea,
        account = @user_1
    )]
    #[expected_failure(abort_code = 4001)] 
    fun test_modify_fee_share_unauth(
        sea_admin: &signer,
        account: &signer
    ) acquires MakerProportion {
        initialize(sea_admin);
        modify_maker_port(account, 800, 200);
        let prop = borrow_global<MakerProportion>(@sea);
        assert!(prop.grid_proportion == 800, 800);
        assert!(prop.order_proportion == 200, 200);
    }

    #[test(sea_admin = @sea)]
    fun test_get_maker_fee_shares(
        sea_admin: &signer
    ) acquires MakerProportion {
        initialize(sea_admin);

        let fee_fixtures = vector<vector<u64>>[
            vector<u64>[1, 0, 1, 0, 1],
            vector<u64>[2, 1, 1, 0, 2],
            vector<u64>[3, 2, 1, 1, 2],
            vector<u64>[4, 3, 1, 1, 3],
            vector<u64>[5, 4, 1, 2, 3],
            vector<u64>[6, 5, 1, 2, 4],
            vector<u64>[7, 6, 1, 2, 5],
            vector<u64>[8, 7, 1, 3, 5],
            vector<u64>[9, 8, 1, 3, 6],
            vector<u64>[10, 9, 1, 4, 6],
        ];
        let i = 0;
        while (i < vector::length(&fee_fixtures)) {
            let item = vector::borrow(&fee_fixtures, i);
            let total = *vector::borrow(item, 0);
            let maker_grid_part = *vector::borrow(item, 1);
            let plat_grid_part = *vector::borrow(item, 2);
            let maker_order_part = *vector::borrow(item, 3);
            let plat_order_part = *vector::borrow(item, 4);
            let (maker_grid_fee, plat_grid_fee) = get_maker_fee_shares(total, true);
            // debug::print(&maker_grid_fee);
            // debug::print(&maker_grid_part);
            assert!(maker_grid_fee == maker_grid_part, i*100+1);
            assert!(plat_grid_fee == plat_grid_part, i*100+2);
            let (maker_order_fee, plat_order_fee) = get_maker_fee_shares(total, false);
            assert!(maker_order_fee == maker_order_part, i*100+3);
            assert!(plat_order_fee == plat_order_part, i*100+4);

            i = i + 1;
        }
    }
}
