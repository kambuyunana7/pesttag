;; Application Tracker Smart Contract
;; Records and monitors pesticide application activities with compliance verification
;; Integrates with pesticide registry for safety validation and regulatory compliance

;; ==== CONSTANTS ====

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-invalid-input (err u202))
(define-constant err-unauthorized (err u203))
(define-constant err-safety-violation (err u204))
(define-constant err-invalid-pesticide (err u205))
(define-constant err-rate-exceeded (err u206))
(define-constant err-too-soon (err u207))
(define-constant err-contract-paused (err u208))
(define-constant err-invalid-applicator (err u209))

;; Application status constants
(define-constant status-pending "PENDING")
(define-constant status-approved "APPROVED")
(define-constant status-completed "COMPLETED")
(define-constant status-cancelled "CANCELLED")
(define-constant status-flagged "FLAGGED")

;; Safety and compliance constants
(define-constant min-application-interval u24) ;; 24 hours minimum between applications
(define-constant max-area-per-application u100000) ;; maximum area in square meters
(define-constant compliance-check-window u168) ;; 7 days for compliance verification

;; Weather condition validation
(define-constant min-weather-description-length u10)
(define-constant max-weather-description-length u100)

;; ==== DATA VARIABLES ====

(define-data-var next-application-id uint u1)
(define-data-var total-applications uint u0)
(define-data-var contract-paused bool false)
(define-data-var compliance-officer principal contract-owner)
(define-data-var safety-inspection-required-threshold uint u5000) ;; area threshold for inspections

;; ==== DATA MAPS ====

;; Main application records
(define-map applications
  { application-id: uint }
  {
    pesticide-id: uint,
    applicator: principal,
    location: (string-ascii 200),
    area-size: uint,
    application-rate: uint,
    application-date: uint,
    weather-conditions: (string-ascii 100),
    equipment-used: (string-ascii 100),
    safety-interval-end: uint,
    status: (string-ascii 20),
    compliance-verified: bool,
    verification-date: (optional uint),
    notes: (string-ascii 500),
    created-at: uint,
    last-updated: uint
  }
)

;; Certified applicator registry
(define-map certified-applicators
  { applicator: principal }
  {
    certification-number: (string-ascii 50),
    certification-date: uint,
    expiry-date: uint,
    is-active: bool,
    specializations: (list 10 (string-ascii 50)),
    applications-count: uint
  }
)

;; Location-based application history for compliance tracking
(define-map location-applications
  { location: (string-ascii 200) }
  {
    application-ids: (list 50 uint),
    last-application-date: uint,
    total-applications: uint
  }
)

;; Pesticide-specific application tracking
(define-map pesticide-applications
  { pesticide-id: uint }
  {
    application-ids: (list 100 uint),
    total-applications: uint,
    last-application: uint,
    total-area-treated: uint
  }
)

;; Compliance violation tracking
(define-map violations
  { application-id: uint }
  {
    violation-type: (string-ascii 100),
    severity: (string-ascii 20),
    description: (string-ascii 300),
    flagged-date: uint,
    resolved: bool,
    resolution-date: (optional uint)
  }
)

;; Daily application summary for monitoring
(define-map daily-stats
  { date: uint }
  {
    applications-count: uint,
    total-area-treated: uint,
    unique-locations: uint,
    compliance-rate: uint
  }
)

;; ==== PUBLIC FUNCTIONS ====

;; Log a new pesticide application
(define-public (log-application
    (pesticide-id uint)
    (location (string-ascii 200))
    (area-size uint)
    (application-rate uint)
    (weather-conditions (string-ascii 100))
    (equipment-used (string-ascii 100))
    (notes (string-ascii 500))
  )
  (let (
    (application-id (var-get next-application-id))
    (current-time burn-block-height)
    (applicator tx-sender)
  )
    ;; Basic validation
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> (len location) u0) err-invalid-input)
    (asserts! (> area-size u0) err-invalid-input)
    (asserts! (<= area-size max-area-per-application) err-invalid-input)
    (asserts! (> application-rate u0) err-invalid-input)
    (asserts! (>= (len weather-conditions) min-weather-description-length) err-invalid-input)
    (asserts! (<= (len weather-conditions) max-weather-description-length) err-invalid-input)
    (asserts! (> (len equipment-used) u0) err-invalid-input)
    
    ;; Verify applicator certification
    (asserts! (is-some (map-get? certified-applicators { applicator: applicator })) err-invalid-applicator)
    
    ;; Calculate safety interval end (this would ideally call pesticide registry)
    (let (
      (safety-interval u72) ;; Default 72 hours - in real implementation, get from registry
      (safety-end (+ current-time safety-interval))
    )
      ;; Check location-based application history for compliance
      (let (
        (location-history (default-to 
          { application-ids: (list), last-application-date: u0, total-applications: u0 }
          (map-get? location-applications { location: location })
        ))
        (last-app-date (get last-application-date location-history))
      )
        ;; Ensure minimum time between applications at same location
        (asserts! (or 
          (is-eq last-app-date u0)
          (>= (- current-time last-app-date) min-application-interval)
        ) err-too-soon)
        
        ;; Create the application record
        (map-set applications
          { application-id: application-id }
          {
            pesticide-id: pesticide-id,
            applicator: applicator,
            location: location,
            area-size: area-size,
            application-rate: application-rate,
            application-date: current-time,
            weather-conditions: weather-conditions,
            equipment-used: equipment-used,
            safety-interval-end: safety-end,
            status: status-pending,
            compliance-verified: false,
            verification-date: none,
            notes: notes,
            created-at: current-time,
            last-updated: current-time
          }
        )
        
        ;; Update location history
        (map-set location-applications
          { location: location }
          {
            application-ids: (unwrap-panic (as-max-len? 
              (append (get application-ids location-history) application-id) u50)),
            last-application-date: current-time,
            total-applications: (+ (get total-applications location-history) u1)
          }
        )
        
        ;; Update pesticide application tracking
        (let (
          (pesticide-history (default-to
            { application-ids: (list), total-applications: u0, last-application: u0, total-area-treated: u0 }
            (map-get? pesticide-applications { pesticide-id: pesticide-id })
          ))
        )
          (map-set pesticide-applications
            { pesticide-id: pesticide-id }
            {
              application-ids: (unwrap-panic (as-max-len?
                (append (get application-ids pesticide-history) application-id) u100)),
              total-applications: (+ (get total-applications pesticide-history) u1),
              last-application: current-time,
              total-area-treated: (+ (get total-area-treated pesticide-history) area-size)
            }
          )
        )
        
        ;; Update applicator statistics
        (match (map-get? certified-applicators { applicator: applicator })
          applicator-info (map-set certified-applicators
            { applicator: applicator }
            (merge applicator-info {
              applications-count: (+ (get applications-count applicator-info) u1)
            })
          )
          false ;; This should not happen due to earlier check
        )
        
        ;; Update global counters
        (var-set next-application-id (+ application-id u1))
        (var-set total-applications (+ (var-get total-applications) u1))
        
        ;; Update daily statistics
        (update-daily-stats current-time area-size)
        
        (ok application-id)
      )
    )
  )
)

;; Register a certified applicator (owner only)
(define-public (register-applicator
    (applicator principal)
    (certification-number (string-ascii 50))
    (expiry-date uint)
    (specializations (list 10 (string-ascii 50)))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len certification-number) u0) err-invalid-input)
    (asserts! (> expiry-date burn-block-height) err-invalid-input)
    
    (map-set certified-applicators
      { applicator: applicator }
      {
        certification-number: certification-number,
        certification-date: burn-block-height,
        expiry-date: expiry-date,
        is-active: true,
        specializations: specializations,
        applications-count: u0
      }
    )
    
    (ok true)
  )
)

;; Verify application compliance (compliance officer only)
(define-public (verify-compliance
    (application-id uint)
    (is-compliant bool)
    (verification-notes (string-ascii 300))
  )
  (let (
    (application (unwrap! (map-get? applications { application-id: application-id }) err-not-found))
    (current-time burn-block-height)
  )
    ;; Authorization check
    (asserts! (or 
      (is-eq tx-sender (var-get compliance-officer))
      (is-eq tx-sender contract-owner)
    ) err-unauthorized)
    
    ;; Update application status
    (map-set applications
      { application-id: application-id }
      (merge application {
        compliance-verified: is-compliant,
        verification-date: (some current-time),
        status: (if is-compliant status-approved status-flagged),
        notes: verification-notes,
        last-updated: current-time
      })
    )
    
    ;; Log violation if not compliant
    (if (not is-compliant)
      (map-set violations
        { application-id: application-id }
        {
          violation-type: "COMPLIANCE_FAILURE",
          severity: "HIGH",
          description: verification-notes,
          flagged-date: current-time,
          resolved: false,
          resolution-date: none
        }
      )
      true
    )
    
    (ok true)
  )
)

;; Complete an application (mark as finished)
(define-public (complete-application (application-id uint))
  (let (
    (application (unwrap! (map-get? applications { application-id: application-id }) err-not-found))
  )
    ;; Only applicator or owner can complete
    (asserts! (or 
      (is-eq tx-sender (get applicator application))
      (is-eq tx-sender contract-owner)
    ) err-unauthorized)
    
    ;; Must be approved or pending
    (asserts! (or 
      (is-eq (get status application) status-approved)
      (is-eq (get status application) status-pending)
    ) err-invalid-input)
    
    (map-set applications
      { application-id: application-id }
      (merge application {
        status: status-completed,
        last-updated: burn-block-height
      })
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

;; Set compliance officer (owner only)
(define-public (set-compliance-officer (officer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set compliance-officer officer)
    (ok true)
  )
)

;; ==== READ-ONLY FUNCTIONS ====

;; Get application details
(define-read-only (get-application (application-id uint))
  (map-get? applications { application-id: application-id })
)

;; Get applicator certification info
(define-read-only (get-applicator-info (applicator principal))
  (map-get? certified-applicators { applicator: applicator })
)

;; Get location application history
(define-read-only (get-location-history (location (string-ascii 200)))
  (map-get? location-applications { location: location })
)

;; Get pesticide application statistics
(define-read-only (get-pesticide-stats (pesticide-id uint))
  (map-get? pesticide-applications { pesticide-id: pesticide-id })
)

;; Get violation details
(define-read-only (get-violation (application-id uint))
  (map-get? violations { application-id: application-id })
)

;; Get daily statistics
(define-read-only (get-daily-stats (date uint))
  (map-get? daily-stats { date: date })
)

;; Get contract status and statistics
(define-read-only (get-contract-status)
  {
    is-paused: (var-get contract-paused),
    total-applications: (var-get total-applications),
    next-application-id: (var-get next-application-id),
    compliance-officer: (var-get compliance-officer),
    inspection-threshold: (var-get safety-inspection-required-threshold)
  }
)

;; Check if applicator is certified and active
(define-read-only (is-applicator-certified (applicator principal))
  (match (map-get? certified-applicators { applicator: applicator })
    info (and 
      (get is-active info)
      (> (get expiry-date info) burn-block-height)
    )
    false
  )
)

;; Check if location needs inspection based on activity
(define-read-only (location-needs-inspection (location (string-ascii 200)))
  (match (map-get? location-applications { location: location })
    history (>= (get total-applications history) u10) ;; 10+ applications trigger inspection
    false
  )
)

;; Get applications requiring compliance verification
(define-read-only (get-pending-verifications)
  ;; This would return a list of application IDs needing verification
  ;; Implementation simplified for demonstration
  (var-get total-applications)
)

;; ==== PRIVATE FUNCTIONS ====

;; Update daily statistics (internal helper)
(define-private (update-daily-stats (current-time uint) (area-treated uint))
  (let (
    (today current-time) ;; Simplified - in real implementation, normalize to day
    (current-stats (default-to
      { applications-count: u0, total-area-treated: u0, unique-locations: u0, compliance-rate: u0 }
      (map-get? daily-stats { date: today })
    ))
  )
    (map-set daily-stats
      { date: today }
      {
        applications-count: (+ (get applications-count current-stats) u1),
        total-area-treated: (+ (get total-area-treated current-stats) area-treated),
        unique-locations: (get unique-locations current-stats), ;; Would need more logic
        compliance-rate: (get compliance-rate current-stats) ;; Would calculate based on verifications
      }
    )
  )
)

