;; Pesticide Registry Smart Contract
;; Manages comprehensive pesticide product database with safety tracking
;; Ensures regulatory compliance and maintains detailed product information

;; ==== CONSTANTS ====

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-expired-product (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-rate (err u106))
(define-constant err-product-suspended (err u107))

;; Product status constants
(define-constant status-active "ACTIVE")
(define-constant status-inactive "INACTIVE")
(define-constant status-suspended "SUSPENDED")
(define-constant status-expired "EXPIRED")

;; Maximum allowed values for safety
(define-constant max-application-rate u10000)
(define-constant max-safety-interval u8760) ;; hours in a year

;; ==== DATA VARIABLES ====

(define-data-var next-product-id uint u1)
(define-data-var total-registered-products uint u0)
(define-data-var contract-paused bool false)
(define-data-var minimum-safety-interval uint u24) ;; 24 hours minimum

;; ==== DATA MAPS ====

;; Main pesticide product registry
(define-map pesticides
  { product-id: uint }
  {
    name: (string-ascii 100),
    active-ingredient: (string-ascii 100),
    manufacturer: principal,
    registration-number: (string-ascii 50),
    safety-interval: uint,
    max-application-rate: uint,
    is-restricted: bool,
    registration-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    last-updated: uint,
    update-count: uint
  }
)

;; Manufacturer registry for authorization
(define-map authorized-manufacturers
  { manufacturer: principal }
  {
    company-name: (string-ascii 100),
    registration-date: uint,
    is-active: bool,
    license-number: (string-ascii 50)
  }
)

;; Product name to ID mapping for quick lookups
(define-map product-name-index
  { name: (string-ascii 100) }
  { product-id: uint }
)

;; Registration number to ID mapping
(define-map registration-index
  { registration-number: (string-ascii 50) }
  { product-id: uint }
)

;; Manufacturer product count tracking
(define-map manufacturer-stats
  { manufacturer: principal }
  {
    product-count: uint,
    last-registration: uint
  }
)

;; ==== PUBLIC FUNCTIONS ====

;; Register a new pesticide product
(define-public (register-pesticide
    (name (string-ascii 100))
    (active-ingredient (string-ascii 100))
    (registration-number (string-ascii 50))
    (safety-interval uint)
    (max-rate uint)
    (is-restricted bool)
    (expiry-date uint)
  )
  (let (
    (product-id (var-get next-product-id))
    (current-time burn-block-height)
  )
    ;; Input validation
    (asserts! (not (var-get contract-paused)) (err u108))
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len active-ingredient) u0) err-invalid-input)
    (asserts! (> (len registration-number) u0) err-invalid-input)
    (asserts! (>= safety-interval (var-get minimum-safety-interval)) err-invalid-input)
    (asserts! (<= safety-interval max-safety-interval) err-invalid-input)
    (asserts! (<= max-rate max-application-rate) err-invalid-rate)
    (asserts! (> expiry-date current-time) err-invalid-input)
    
    ;; Check for duplicates
    (asserts! (is-none (map-get? product-name-index { name: name })) err-already-exists)
    (asserts! (is-none (map-get? registration-index { registration-number: registration-number })) err-already-exists)
    
    ;; Register the pesticide
    (map-set pesticides
      { product-id: product-id }
      {
        name: name,
        active-ingredient: active-ingredient,
        manufacturer: tx-sender,
        registration-number: registration-number,
        safety-interval: safety-interval,
        max-application-rate: max-rate,
        is-restricted: is-restricted,
        registration-date: current-time,
        expiry-date: expiry-date,
        status: status-active,
        last-updated: current-time,
        update-count: u1
      }
    )
    
    ;; Update indexes
    (map-set product-name-index { name: name } { product-id: product-id })
    (map-set registration-index { registration-number: registration-number } { product-id: product-id })
    
    ;; Update manufacturer stats
    (match (map-get? manufacturer-stats { manufacturer: tx-sender })
      stats (map-set manufacturer-stats
        { manufacturer: tx-sender }
        {
          product-count: (+ (get product-count stats) u1),
          last-registration: current-time
        }
      )
      (map-set manufacturer-stats
        { manufacturer: tx-sender }
        {
          product-count: u1,
          last-registration: current-time
        }
      )
    )
    
    ;; Update global counters
    (var-set next-product-id (+ product-id u1))
    (var-set total-registered-products (+ (var-get total-registered-products) u1))
    
    (ok product-id)
  )
)

;; Update pesticide product information
(define-public (update-pesticide
    (product-id uint)
    (safety-interval uint)
    (max-rate uint)
    (expiry-date uint)
    (status (string-ascii 20))
  )
  (let (
    (product (unwrap! (map-get? pesticides { product-id: product-id }) err-not-found))
    (current-time burn-block-height)
  )
    ;; Authorization check
    (asserts! (is-eq tx-sender (get manufacturer product)) err-unauthorized)
    
    ;; Input validation
    (asserts! (>= safety-interval (var-get minimum-safety-interval)) err-invalid-input)
    (asserts! (<= safety-interval max-safety-interval) err-invalid-input)
    (asserts! (<= max-rate max-application-rate) err-invalid-rate)
    (asserts! (> expiry-date current-time) err-invalid-input)
    
    ;; Update the product
    (map-set pesticides
      { product-id: product-id }
      (merge product {
        safety-interval: safety-interval,
        max-application-rate: max-rate,
        expiry-date: expiry-date,
        status: status,
        last-updated: current-time,
        update-count: (+ (get update-count product) u1)
      })
    )
    
    (ok true)
  )
)

;; Suspend a pesticide product (owner only)
(define-public (suspend-product (product-id uint))
  (let (
    (product (unwrap! (map-get? pesticides { product-id: product-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set pesticides
      { product-id: product-id }
      (merge product {
        status: status-suspended,
        last-updated: burn-block-height,
        update-count: (+ (get update-count product) u1)
      })
    )
    
    (ok true)
  )
)

;; Register a manufacturer (owner only)
(define-public (register-manufacturer
    (manufacturer principal)
    (company-name (string-ascii 100))
    (license-number (string-ascii 50))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len company-name) u0) err-invalid-input)
    (asserts! (> (len license-number) u0) err-invalid-input)
    
    (map-set authorized-manufacturers
      { manufacturer: manufacturer }
      {
        company-name: company-name,
        registration-date: burn-block-height,
        is-active: true,
        license-number: license-number
      }
    )
    
    (ok true)
  )
)

;; Emergency pause contract (owner only)
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

;; Resume contract operations (owner only)
(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

;; ==== READ-ONLY FUNCTIONS ====

;; Get pesticide details by ID
(define-read-only (get-pesticide (product-id uint))
  (map-get? pesticides { product-id: product-id })
)

;; Get pesticide ID by name
(define-read-only (get-product-id-by-name (name (string-ascii 100)))
  (map-get? product-name-index { name: name })
)

;; Get pesticide ID by registration number
(define-read-only (get-product-id-by-registration (registration-number (string-ascii 50)))
  (map-get? registration-index { registration-number: registration-number })
)

;; Check if pesticide is active and valid
(define-read-only (is-pesticide-valid (product-id uint))
  (match (map-get? pesticides { product-id: product-id })
    product
      (and
        (is-eq (get status product) status-active)
        (> (get expiry-date product) burn-block-height)
      )
    false
  )
)

;; Get manufacturer information
(define-read-only (get-manufacturer-info (manufacturer principal))
  (map-get? authorized-manufacturers { manufacturer: manufacturer })
)

;; Get manufacturer statistics
(define-read-only (get-manufacturer-stats (manufacturer principal))
  (map-get? manufacturer-stats { manufacturer: manufacturer })
)

;; Get total registered products
(define-read-only (get-total-products)
  (var-get total-registered-products)
)

;; Get contract status
(define-read-only (get-contract-status)
  {
    is-paused: (var-get contract-paused),
    total-products: (var-get total-registered-products),
    next-id: (var-get next-product-id),
    minimum-safety-interval: (var-get minimum-safety-interval)
  }
)

;; Check if product is expired
(define-read-only (is-product-expired (product-id uint))
  (match (map-get? pesticides { product-id: product-id })
    product (<= (get expiry-date product) burn-block-height)
    true
  )
)

;; Validate application rate against product limits
(define-read-only (validate-application-rate (product-id uint) (proposed-rate uint))
  (match (map-get? pesticides { product-id: product-id })
    product (<= proposed-rate (get max-application-rate product))
    false
  )
)

