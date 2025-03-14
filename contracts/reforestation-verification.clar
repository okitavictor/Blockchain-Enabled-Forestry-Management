;; Reforestation Verification Contract
;; Tracks replanting efforts and growth

(define-data-var admin principal tx-sender)

;; Map of reforestation project IDs to project details
(define-map reforestation-projects
  uint
  {
    parcel-id: uint,
    owner: principal,
    area-hectares: uint,
    species-planted: (string-ascii 100),
    trees-planted: uint,
    planting-date: uint,
    last-verification-date: uint,
    growth-stage: (string-ascii 20), ;; "seedling", "sapling", "young", "mature"
    survival-rate: uint, ;; percentage (0-100)
    verified: bool
  }
)

;; Map of approved verifiers
(define-map verifiers
  principal
  { active: bool }
)

;; Map to track parcel details (simplified from land-parcel-registration)
(define-map parcels
  uint
  {
    owner: principal,
    area-hectares: uint
  }
)

;; Counter for project IDs
(define-data-var next-project-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Add a verifier
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set verifiers verifier { active: true })
    (ok true)
  )
)

;; Remove a verifier
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set verifiers verifier { active: false })
    (ok true)
  )
)

;; Set parcel details (admin function to sync with land-parcel-registration)
(define-public (set-parcel-details (parcel-id uint) (owner principal) (area-hectares uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set parcels parcel-id { owner: owner, area-hectares: area-hectares })
    (ok true)
  )
)

;; Register a new reforestation project
(define-public (register-project
  (parcel-id uint)
  (area-hectares uint)
  (species-planted (string-ascii 100))
  (trees-planted uint)
)
  (let (
    (parcel (unwrap! (map-get? parcels parcel-id) (err u3)))
    (project-id (var-get next-project-id))
  )
    ;; Only parcel owner can register projects
    (asserts! (is-eq tx-sender (get owner parcel)) (err u4))
    ;; Cannot reforest more than the parcel area
    (asserts! (<= area-hectares (get area-hectares parcel)) (err u5))
    ;; Ensure reasonable tree density (example: max 2500 trees per hectare)
    (asserts! (<= trees-planted (* area-hectares u2500)) (err u6))

    ;; Create the project
    (map-set reforestation-projects
      project-id
      {
        parcel-id: parcel-id,
        owner: tx-sender,
        area-hectares: area-hectares,
        species-planted: species-planted,
        trees-planted: trees-planted,
        planting-date: block-height,
        last-verification-date: block-height,
        growth-stage: "seedling",
        survival-rate: u100, ;; Assume 100% initially
        verified: false
      }
    )

    ;; Increment the project ID counter
    (var-set next-project-id (+ project-id u1))

    (ok project-id)
  )
)

;; Verify a reforestation project
(define-public (verify-project
  (project-id uint)
  (growth-stage (string-ascii 20))
  (survival-rate uint)
)
  (let (
    (project (unwrap! (map-get? reforestation-projects project-id) (err u7)))
    (verifier-data (unwrap! (map-get? verifiers tx-sender) (err u8)))
  )
    ;; Only active verifiers can verify projects
    (asserts! (get active verifier-data) (err u8))
    ;; Survival rate cannot exceed 100%
    (asserts! (<= survival-rate u100) (err u9))

    ;; Update the project
    (map-set reforestation-projects
      project-id
      (merge project {
        last-verification-date: block-height,
        growth-stage: growth-stage,
        survival-rate: survival-rate,
        verified: true
      })
    )

    (ok true)
  )
)

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? reforestation-projects project-id)
)

;; Calculate effective trees (surviving trees)
(define-read-only (get-effective-trees (project-id uint))
  (match (map-get? reforestation-projects project-id)
    project (/ (* (get trees-planted project) (get survival-rate project)) u100)
    u0)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u10))
    (var-set admin new-admin)
    (ok true)
  )
)

