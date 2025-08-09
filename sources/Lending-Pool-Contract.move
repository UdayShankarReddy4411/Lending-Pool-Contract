module Uday_addr::LendingPool {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing a lending pool position
    struct LendingPosition has store, key {
        collateral_amount: u64,     // Amount of collateral deposited
        borrowed_amount: u64,       // Amount borrowed
        interest_rate: u64,         // Interest rate per second (basis points)
        last_update_time: u64,      // Last time interest was calculated
        is_active: bool,            // Whether the position is active
    }

    /// Pool configuration constants
    const COLLATERALIZATION_RATIO: u64 = 150; // 150% collateralization required
    const INTEREST_RATE: u64 = 100; // 1% per year in basis points per second
    const LIQUIDATION_THRESHOLD: u64 = 120; // 120% liquidation threshold

    /// Error codes
    const E_INSUFFICIENT_COLLATERAL: u64 = 1;
    const E_NO_ACTIVE_POSITION: u64 = 2;

    /// Function to deposit collateral and borrow tokens
    public fun borrow_with_collateral(
        borrower: &signer, 
        collateral_amount: u64, 
        borrow_amount: u64
    ) {
        let borrower_addr = signer::address_of(borrower);
        
        // Check collateralization ratio
        assert!(
            collateral_amount * 100 >= borrow_amount * COLLATERALIZATION_RATIO,
            E_INSUFFICIENT_COLLATERAL
        );

        // Transfer collateral from borrower to contract
        let collateral = coin::withdraw<AptosCoin>(borrower, collateral_amount);
        coin::deposit<AptosCoin>(borrower_addr, collateral);

        // Create lending position
        let position = LendingPosition {
            collateral_amount,
            borrowed_amount: borrow_amount,
            interest_rate: INTEREST_RATE,
            last_update_time: timestamp::now_seconds(),
            is_active: true,
        };

        move_to(borrower, position);
    }

    /// Function to repay loan and withdraw collateral
    public fun repay_and_withdraw(borrower: &signer) acquires LendingPosition {
        let borrower_addr = signer::address_of(borrower);
        let position = borrow_global_mut<LendingPosition>(borrower_addr);
        
        assert!(position.is_active, E_NO_ACTIVE_POSITION);

        // Calculate accumulated interest
        let current_time = timestamp::now_seconds();
        let time_elapsed = current_time - position.last_update_time;
        let interest = (position.borrowed_amount * position.interest_rate * time_elapsed) / 10000;
        let total_repayment = position.borrowed_amount + interest;

        // Repay the loan with interest
        let repayment = coin::withdraw<AptosCoin>(borrower, total_repayment);
        coin::deposit<AptosCoin>(borrower_addr, repayment);

        // Return collateral to borrower
        let collateral_return = coin::withdraw<AptosCoin>(borrower, position.collateral_amount);
        coin::deposit<AptosCoin>(borrower_addr, collateral_return);

        // Close the position
        position.is_active = false;
        position.borrowed_amount = 0;
        position.collateral_amount = 0;
    }
}