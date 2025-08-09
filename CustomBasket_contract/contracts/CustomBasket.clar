
;; title: CustomBasket
;; version: 1.0.0
;; summary: Synthetic Assets - Create synthetic exposure to traditional assets through user-defined multi-asset synthetic portfolios
;; description: A smart contract that allows users to create, manage, and trade synthetic asset baskets representing exposure to traditional assets

;; traits
;;

;; token definitions
(define-fungible-token synthetic-basket)

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-BASKET-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-ASSET (err u105))
(define-constant ERR-BASKET-EXISTS (err u106))
(define-constant ERR-INVALID-WEIGHT (err u107))
(define-constant ERR-MAX-ASSETS-EXCEEDED (err u108))
(define-constant ERR-UNAUTHORIZED (err u109))

(define-constant MAX-ASSETS-PER-BASKET u10)
(define-constant PRECISION u1000000) ;; 6 decimal precision

;; data vars
(define-data-var next-basket-id uint u1)
(define-data-var protocol-fee uint u100) ;; 0.01% fee (100/1000000)
(define-data-var fee-collector principal CONTRACT-OWNER)

;; data maps
;; Basket configuration
(define-map baskets 
  { basket-id: uint }
  {
    creator: principal,
    name: (string-ascii 32),
    description: (string-ascii 128),
    total-supply: uint,
    creation-time: uint,
    is-active: bool
  }
)

;; Asset composition within baskets
(define-map basket-assets 
  { basket-id: uint, asset-symbol: (string-ascii 16) }
  {
    weight: uint, ;; Weight as percentage * PRECISION (e.g., 25% = 250000)
    price-feed: (optional principal), ;; Price oracle contract
    last-price: uint
  }
)

;; User basket token balances
(define-map user-balances 
  { user: principal, basket-id: uint }
  { balance: uint }
)

;; Approved asset symbols for baskets
(define-map approved-assets
  { asset-symbol: (string-ascii 16) }
  { is-approved: bool, price-feed: (optional principal) }
)

;; Total value locked per basket
(define-map basket-tvl 
  { basket-id: uint }
  { tvl: uint }
)

;; public functions

;; Initialize approved assets (owner only)
(define-public (add-approved-asset (asset-symbol (string-ascii 16)) (price-feed (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (map-set approved-assets 
      { asset-symbol: asset-symbol }
      { is-approved: true, price-feed: price-feed }
    ))
  )
)

;; Create a new synthetic basket
(define-public (create-basket 
  (name (string-ascii 32)) 
  (description (string-ascii 128))
  (assets (list 10 { symbol: (string-ascii 16), weight: uint })))
  (let
    (
      (basket-id (var-get next-basket-id))
      (total-weight (fold + (map get-weight assets) u0))
    )
    ;; Validate total weight equals 100%
    (asserts! (is-eq total-weight (* u100 PRECISION)) ERR-INVALID-WEIGHT)
    
    ;; Validate all assets are approved
    (asserts! (is-eq (len (filter is-asset-approved assets)) (len assets)) ERR-INVALID-ASSET)
    
    ;; Validate max assets limit
    (asserts! (<= (len assets) MAX-ASSETS-PER-BASKET) ERR-MAX-ASSETS-EXCEEDED)
    
    ;; Create basket
    (map-set baskets 
      { basket-id: basket-id }
      {
        creator: tx-sender,
        name: name,
        description: description,
        total-supply: u0,
        creation-time: block-height,
        is-active: true
      }
    )
    
    ;; Add assets to basket
    (fold add-asset-to-basket-fold assets basket-id)
    
    ;; Initialize TVL
    (map-set basket-tvl { basket-id: basket-id } { tvl: u0 })
    
    ;; Increment next basket ID
    (var-set next-basket-id (+ basket-id u1))
    
    (ok basket-id)
  )
)

;; Mint basket tokens by providing underlying assets
(define-public (mint-basket-tokens (basket-id uint) (amount uint))
  (let
    (
      (basket-info (unwrap! (map-get? baskets { basket-id: basket-id }) ERR-BASKET-NOT-FOUND))
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender, basket-id: basket-id }))))
      (protocol-fee-amount (/ (* amount (var-get protocol-fee)) PRECISION))
      (net-amount (- amount protocol-fee-amount))
    )
    ;; Validate basket is active
    (asserts! (get is-active basket-info) ERR-BASKET-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Mint synthetic tokens
    (try! (ft-mint? synthetic-basket net-amount tx-sender))
    
    ;; Update user balance
    (map-set user-balances 
      { user: tx-sender, basket-id: basket-id }
      { balance: (+ current-balance net-amount) }
    )
    
    ;; Update basket total supply
    (map-set baskets 
      { basket-id: basket-id }
      (merge basket-info { total-supply: (+ (get total-supply basket-info) net-amount) })
    )
    
    ;; Update TVL
    (let ((current-tvl (default-to u0 (get tvl (map-get? basket-tvl { basket-id: basket-id })))))
      (map-set basket-tvl 
        { basket-id: basket-id }
        { tvl: (+ current-tvl amount) }
      )
    )
    
    ;; Transfer protocol fee
    (if (> protocol-fee-amount u0)
      (try! (ft-mint? synthetic-basket protocol-fee-amount (var-get fee-collector)))
      true
    )
    
    (ok net-amount)
  )
)

;; Burn basket tokens to redeem underlying value
(define-public (burn-basket-tokens (basket-id uint) (amount uint))
  (let
    (
      (basket-info (unwrap! (map-get? baskets { basket-id: basket-id }) ERR-BASKET-NOT-FOUND))
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender, basket-id: basket-id }))))
    )
    ;; Validate sufficient balance
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Burn synthetic tokens
    (try! (ft-burn? synthetic-basket amount tx-sender))
    
    ;; Update user balance
    (map-set user-balances 
      { user: tx-sender, basket-id: basket-id }
      { balance: (- current-balance amount) }
    )
    
    ;; Update basket total supply
    (map-set baskets 
      { basket-id: basket-id }
      (merge basket-info { total-supply: (- (get total-supply basket-info) amount) })
    )
    
    ;; Update TVL
    (let ((current-tvl (default-to u0 (get tvl (map-get? basket-tvl { basket-id: basket-id })))))
      (map-set basket-tvl 
        { basket-id: basket-id }
        { tvl: (if (> current-tvl amount) (- current-tvl amount) u0) }
      )
    )
    
    (ok amount)
  )
)

;; Transfer basket tokens between users
(define-public (transfer-basket-tokens (basket-id uint) (amount uint) (recipient principal))
  (let
    (
      (sender-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender, basket-id: basket-id }))))
      (recipient-balance (default-to u0 (get balance (map-get? user-balances { user: recipient, basket-id: basket-id }))))
    )
    ;; Validate sufficient balance
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update sender balance
    (map-set user-balances 
      { user: tx-sender, basket-id: basket-id }
      { balance: (- sender-balance amount) }
    )
    
    ;; Update recipient balance
    (map-set user-balances 
      { user: recipient, basket-id: basket-id }
      { balance: (+ recipient-balance amount) }
    )
    
    (ok amount)
  )
)

;; Deactivate a basket (creator only)
(define-public (deactivate-basket (basket-id uint))
  (let
    (
      (basket-info (unwrap! (map-get? baskets { basket-id: basket-id }) ERR-BASKET-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator basket-info)) ERR-UNAUTHORIZED)
    
    (ok (map-set baskets 
      { basket-id: basket-id }
      (merge basket-info { is-active: false })
    ))
  )
)

;; Update protocol fee (owner only)
(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (var-set protocol-fee new-fee))
  )
)

;; read only functions

;; Get basket information
(define-read-only (get-basket-info (basket-id uint))
  (map-get? baskets { basket-id: basket-id })
)

;; Get user balance for a specific basket
(define-read-only (get-user-basket-balance (user principal) (basket-id uint))
  (default-to u0 (get balance (map-get? user-balances { user: user, basket-id: basket-id })))
)

;; Get basket asset composition
(define-read-only (get-basket-asset (basket-id uint) (asset-symbol (string-ascii 16)))
  (map-get? basket-assets { basket-id: basket-id, asset-symbol: asset-symbol })
)

;; Get total basket count
(define-read-only (get-total-baskets)
  (- (var-get next-basket-id) u1)
)

;; Get protocol fee
(define-read-only (get-protocol-fee)
  (var-get protocol-fee)
)

;; Check if asset is approved
(define-read-only (is-approved-asset (asset-symbol (string-ascii 16)))
  (default-to false (get is-approved (map-get? approved-assets { asset-symbol: asset-symbol })))
)

;; Get basket TVL
(define-read-only (get-basket-tvl (basket-id uint))
  (default-to u0 (get tvl (map-get? basket-tvl { basket-id: basket-id })))
)

;; Get synthetic basket token balance
(define-read-only (get-balance (user principal))
  (ft-get-balance synthetic-basket user)
)

;; Get total supply of synthetic basket tokens
(define-read-only (get-total-supply)
  (ft-get-supply synthetic-basket)
)

;; private functions

;; Helper function to get weight from asset tuple
(define-private (get-weight (asset { symbol: (string-ascii 16), weight: uint }))
  (get weight asset)
)

;; Helper function to check if asset is approved
(define-private (is-asset-approved (asset { symbol: (string-ascii 16), weight: uint }))
  (is-approved-asset (get symbol asset))
)

;; Helper function to add asset to basket using fold
(define-private (add-asset-to-basket-fold (asset { symbol: (string-ascii 16), weight: uint }) (basket-id uint))
  (let
    (
      (asset-info (default-to { is-approved: false, price-feed: none } (map-get? approved-assets { asset-symbol: (get symbol asset) })))
    )
    (begin
      (map-set basket-assets 
        { basket-id: basket-id, asset-symbol: (get symbol asset) }
        {
          weight: (get weight asset),
          price-feed: (get price-feed asset-info),
          last-price: u0
        }
      )
      basket-id
    )
  )
)
