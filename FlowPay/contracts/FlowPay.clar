;; FlowPay - Dynamic Payment Flow Management System
;; A smart contract for automated payment channels and progressive value distribution on Stacks

;; Constants
(define-constant system-admin tx-sender)
(define-constant err-admin-only (err u600))
(define-constant err-channel-not-found (err u601))
(define-constant err-funds-insufficient (err u602))
(define-constant err-invalid-input (err u603))
(define-constant err-channel-closed (err u604))
(define-constant err-access-denied (err u605))

;; Data Variables
(define-data-var platform-fee-rate uint u300) ;; 3% platform fee
(define-data-var min-channel-size uint u1000) ;; Minimum 1000 micro-STX per channel

;; Data Maps
(define-map flow-channels
    { channel-id: uint }
    {
        payer: principal,
        payee: principal,
        rate-per-block: uint,
        deposited-amount: uint,
        creation-block: uint,
        expiration-block: uint,
        claimed-amount: uint,
        channel-active: bool
    }
)

(define-map user-wallets
    { user-address: principal }
    { wallet-balance: uint }
)

(define-map channel-registry
    { registry-key: bool }
    { next-channel-id: uint }
)

;; Initialize channel registry
(map-set channel-registry { registry-key: true } { next-channel-id: u0 })

;; Read-only functions

(define-read-only (get-channel-info (channel-id uint))
    (map-get? flow-channels { channel-id: channel-id })
)

(define-read-only (get-user-wallet-balance (user-address principal))
    (default-to u0 (get wallet-balance (map-get? user-wallets { user-address: user-address })))
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (get-min-channel-size)
    (var-get min-channel-size)
)

(define-read-only (compute-claimable-amount (channel-id uint))
    (match (map-get? flow-channels { channel-id: channel-id })
        channel-info
        (let
            (
                (current-block stacks-block-height)
                (creation-block (get creation-block channel-info))
                (expiration-block (get expiration-block channel-info))
                (rate-per-block (get rate-per-block channel-info))
                (claimed-amount (get claimed-amount channel-info))
                (channel-active (get channel-active channel-info))
            )
            (if (and channel-active (>= current-block creation-block))
                (let
                    (
                        (blocks-processed (if (>= current-block expiration-block)
                                         (- expiration-block creation-block)
                                         (- current-block creation-block)))
                        (accumulated-total (* blocks-processed rate-per-block))
                    )
                    (if (>= accumulated-total claimed-amount)
                        (ok (- accumulated-total claimed-amount))
                        (ok u0)
                    )
                )
                (ok u0)
            )
        )
        (err err-channel-not-found)
    )
)

;; Public functions

(define-public (add-funds (amount uint))
    (let
        (
            (current-balance (get-user-wallet-balance tx-sender))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-wallets 
            { user-address: tx-sender } 
            { wallet-balance: (+ current-balance amount) }
        )
        (ok true)
    )
)

(define-public (remove-funds (amount uint))
    (let
        (
            (current-balance (get-user-wallet-balance tx-sender))
        )
        (asserts! (>= current-balance amount) err-funds-insufficient)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-wallets 
            { user-address: tx-sender } 
            { wallet-balance: (- current-balance amount) }
        )
        (ok true)
    )
)

(define-public (establish-flow-channel (payee principal) (rate-per-block uint) (channel-lifespan uint))
    (let
        (
            (channel-id (+ (default-to u0 (get next-channel-id (map-get? channel-registry { registry-key: true }))) u1))
            (deposited-amount (* rate-per-block channel-lifespan))
            (payer-balance (get-user-wallet-balance tx-sender))
        )
        ;; Validate inputs
        (asserts! (>= deposited-amount (var-get min-channel-size)) err-invalid-input)
        (asserts! (> rate-per-block u0) err-invalid-input)
        (asserts! (> channel-lifespan u0) err-invalid-input)
        (asserts! (>= payer-balance deposited-amount) err-funds-insufficient)
        
        ;; Deduct funds from payer balance
        (map-set user-wallets 
            { user-address: tx-sender } 
            { wallet-balance: (- payer-balance deposited-amount) }
        )
        
        ;; Establish flow channel
        (map-set flow-channels
            { channel-id: channel-id }
            {
                payer: tx-sender,
                payee: payee,
                rate-per-block: rate-per-block,
                deposited-amount: deposited-amount,
                creation-block: stacks-block-height,
                expiration-block: (+ stacks-block-height channel-lifespan),
                claimed-amount: u0,
                channel-active: true
            }
        )
        
        ;; Update channel registry
        (map-set channel-registry { registry-key: true } { next-channel-id: channel-id })
        
        (ok channel-id)
    )
)

(define-public (collect-payment (channel-id uint))
    (match (map-get? flow-channels { channel-id: channel-id })
        channel-info
        (let
            (
                (payee (get payee channel-info))
                (claimable-result (compute-claimable-amount channel-id))
            )
            (asserts! (is-eq tx-sender payee) err-access-denied)
            (asserts! (get channel-active channel-info) err-channel-closed)
            
            (match claimable-result
                claimable-amount
                (if (> claimable-amount u0)
                    (let
                        (
                            (platform-fee (/ (* claimable-amount (var-get platform-fee-rate)) u10000))
                            (net-collection (- claimable-amount platform-fee))
                            (current-claimed (get claimed-amount channel-info))
                        )
                        ;; Send payment to payee
                        (try! (as-contract (stx-transfer? net-collection tx-sender payee)))
                        
                        ;; Send platform fee to admin
                        (try! (as-contract (stx-transfer? platform-fee tx-sender system-admin)))
                        
                        ;; Update channel claimed amount
                        (map-set flow-channels
                            { channel-id: channel-id }
                            (merge channel-info { claimed-amount: (+ current-claimed claimable-amount) })
                        )
                        
                        (ok net-collection)
                    )
                    (ok u0)
                )
                error-code
                error-code
            )
        )
        err-channel-not-found
    )
)

(define-public (close-flow-channel (channel-id uint))
    (match (map-get? flow-channels { channel-id: channel-id })
        channel-info
        (let
            (
                (payer (get payer channel-info))
                (payee (get payee channel-info))
                (deposited-amount (get deposited-amount channel-info))
                (claimed-amount (get claimed-amount channel-info))
            )
            (asserts! (or (is-eq tx-sender payer) (is-eq tx-sender payee)) err-access-denied)
            (asserts! (get channel-active channel-info) err-channel-closed)
            
            ;; Process any remaining claimable payment for payee
            (match (compute-claimable-amount channel-id)
                claimable-amount
                (if (> claimable-amount u0)
                    (let
                        (
                            (platform-fee (/ (* claimable-amount (var-get platform-fee-rate)) u10000))
                            (net-collection (- claimable-amount platform-fee))
                        )
                        (try! (as-contract (stx-transfer? net-collection tx-sender payee)))
                        (try! (as-contract (stx-transfer? platform-fee tx-sender system-admin)))
                        (map-set flow-channels
                            { channel-id: channel-id }
                            (merge channel-info { claimed-amount: (+ claimed-amount claimable-amount) })
                        )
                        true
                    )
                    true
                )
                error-code
                false
            )
            
            ;; Return remaining funds to payer
            (let
                (
                    (final-claimed (get claimed-amount (unwrap-panic (map-get? flow-channels { channel-id: channel-id }))))
                    (unused-funds (- deposited-amount final-claimed))
                    (payer-balance (get-user-wallet-balance payer))
                )
                (if (> unused-funds u0)
                    (map-set user-wallets 
                        { user-address: payer } 
                        { wallet-balance: (+ payer-balance unused-funds) }
                    )
                    true
                )
            )
            
            ;; Mark channel as closed
            (map-set flow-channels
                { channel-id: channel-id }
                (merge channel-info { channel-active: false })
            )
            
            (ok true)
        )
        err-channel-not-found
    )
)

;; Admin functions

(define-public (modify-platform-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender system-admin) err-admin-only)
        (asserts! (<= new-fee-rate u2000) err-invalid-input) ;; Max 20% fee
        (var-set platform-fee-rate new-fee-rate)
        (ok true)
    )
)

(define-public (modify-min-channel-size (new-minimum uint))
    (begin
        (asserts! (is-eq tx-sender system-admin) err-admin-only)
        (var-set min-channel-size new-minimum)
        (ok true)
    )
)