;; Harvesting Permit Contract
;; Manages sustainable logging authorizations

(define-data-var admin principal tx-sender)

;; Map of permit IDs to permit details
(define-map permits
  uint
  {
    parcel-id: uint,
    owner: principal,
    max-harvest-volume: uint,
    current-harvest-volume: uint,
    start-date: uint,
    expiry-date: uint,
    status: (string-ascii 20), ;; "active", "completed", "expired", "revoked"
    sustainable-practices: bool
  }
)

;; Map to track parcel details (simplified from land-parcel-registration)
(define-map parcels
  uint
  {
    owner: principal,
    area-hectares: uint,
    protected-status: bool
  }
)

;; Counter for permit IDs
(define-data-var next-permit-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Set parcel details (admin function to sync with land-parcel-registration)
(define-public (set-parcel-details (parcel-id uint) (owner principal) (area-hectares uint) (protected-status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set parcels parcel-id {
      owner: owner,
      area-hectares: area-hectares,
      protected-status: protected-status
    })
    (ok true)
  )
)

;; Apply for a harvesting permit
(define-public (apply-for-permit
  (parcel-id uint)
  (max-harvest-volume uint)
  (duration-days uint)
  (sustainable-practices bool)
)
  (let (
    (parcel (unwrap! (map-get? parcels parcel-id) (err u3)))
    (permit-id (var-get next-permit-id))
  )
    ;; Only parcel owner can apply for permit
    (asserts! (is-eq tx-sender (get owner parcel)) (err u4))
    ;; Cannot harvest protected parcels
    (asserts! (not (get protected-status parcel)) (err u5))
    ;; Ensure harvest volume is reasonable (example: max 50 cubic meters per hectare)
    (asserts! (<= max-harvest-volume (* (get area-hectares parcel) u50)) (err u6))

    ;; Create the permit
    (map-set permits
      permit-id
      {
        parcel-id: parcel-id,
        owner: tx-sender,
        max-harvest-volume: max-harvest-volume,
        current-harvest-volume: u0,
        start-date: block-height,
        expiry-date: (+ block-height (* duration-days u144)), ;; ~144 blocks per day
        status: "active",
        sustainable-practices: sustainable-practices
      }
    )

    ;; Increment the permit ID counter
    (var-set next-permit-id (+ permit-id u1))

    (ok permit-id)
  )
)

;; Record harvesting activity
(define-public (record-harvest (permit-id uint) (harvest-volume uint))
  (let (
    (permit (unwrap! (map-get? permits permit-id) (err u7)))
    (current-volume (get current-harvest-volume permit))
    (new-volume (+ current-volume harvest-volume))
  )
    ;; Only permit owner can record harvest
    (asserts! (is-eq tx-sender (get owner permit)) (err u8))
    ;; Permit must be active
    (asserts! (is-eq (get status permit) "active") (err u9))
    ;; Permit must not be expired
    (asserts! (< block-height (get expiry-date permit)) (err u10))
    ;; Cannot exceed max harvest volume
    (asserts! (<= new-volume (get max-harvest-volume permit)) (err u11))

    ;; Update the permit
    (map-set permits
      permit-id
      (merge permit {
        current-harvest-volume: new-volume,
        status: (if (is-eq new-volume (get max-harvest-volume permit)) "completed" "active")
      })
    )

    (ok true)
  )
)

;; Revoke a permit (admin only)
(define-public (revoke-permit (permit-id uint))
  (let (
    (permit (unwrap! (map-get? permits permit-id) (err u7)))
  )
    ;; Only admin can revoke permits
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Update the permit
    (map-set permits
      permit-id
      (merge permit { status: "revoked" })
    )

    (ok true)
  )
)

;; Get permit details
(define-read-only (get-permit (permit-id uint))
  (map-get? permits permit-id)
)

;; Check if a permit is active
(define-read-only (is-permit-active (permit-id uint))
  (match (map-get? permits permit-id)
    permit (and
             (is-eq (get status permit) "active")
             (< block-height (get expiry-date permit)))
    false)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u12))
    (var-set admin new-admin)
    (ok true)
  )
)

