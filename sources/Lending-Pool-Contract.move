module Uday_addr::LendingPool {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    struct LendingPosition has store, key {
        collateral_amount: u64,     
        borrowed_amount: u64,       
        interest_rate: u64,         
        last_update_time: u64,      
        is_active: bool,            
    }

    const COLLATERALIZATION_RATIO: u64 = 150; 
    const INTEREST_RATE: u64 = 100; 
    const LIQUIDATION_THRESHOLD: u64 = 120; 

    const E_INSUFFICIENT_COLLATERAL: u64 = 1;
    const E_NO_ACTIVE_POSITION: u64 = 2;

    public fun borrow_with_collateral(
        borrower: &signer, 
        collateral_amount: u64, 
        borrow_amount: u64
    ) {
        let borrower_addr = signer::address_of(borrower);
        
        assert!(
            collateral_amount * 100 >= borrow_amount * COLLATERALIZATION_RATIO,
            E_INSUFFICIENT_COLLATERAL
        );

        let collateral = coin::withdraw<AptosCoin>(borrower, collateral_amount);
        coin::deposit<AptosCoin>(borrower_addr, collateral);

        let position = LendingPosition {
            collateral_amount,
            borrowed_amount: borrow_amount,
            interest_rate: INTEREST_RATE,
            last_update_time: timestamp::now_seconds(),
            is_active: true,
        };

        move_to(borrower, position);
    }

    public fun repay_and_withdraw(borrower: &signer) acquires LendingPosition {
        let borrower_addr = signer::address_of(borrower);
        let position = borrow_global_mut<LendingPosition>(borrower_addr);
        
        assert!(position.is_active, E_NO_ACTIVE_POSITION);

        let current_time = timestamp::now_seconds();
        let time_elapsed = current_time - position.last_update_time;
        let interest = (position.borrowed_amount * position.interest_rate * time_elapsed) / 10000;
        let total_repayment = position.borrowed_amount + interest;

        let repayment = coin::withdraw<AptosCoin>(borrower, total_repayment);
        coin::deposit<AptosCoin>(borrower_addr, repayment);

        let collateral_return = coin::withdraw<AptosCoin>(borrower, position.collateral_amount);
        coin::deposit<AptosCoin>(borrower_addr, collateral_return);

        position.is_active = false;
        position.borrowed_amount = 0;
        position.collateral_amount = 0;
    }

}
