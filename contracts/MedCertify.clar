;; MedCertify - Medical device certification and compliance tracking system
(define-map medical-devices uint {
  manufacturer: principal,
  device-model: (string-utf8 64),
  regulatory-standards: (string-utf8 256),
  production-batch: uint,
  facility-code: (string-utf8 64),
  certified: bool
})

(define-map manufacturer-catalog principal (list 100 uint))
(define-map medical-inspectors principal bool)
(define-data-var device-id-counter uint u0)

;; Error codes
(define-constant err-unauthorized-manufacturer (err u700))
(define-constant err-unauthorized-inspector (err u701))
(define-constant err-device-not-found (err u702))
(define-constant err-access-denied (err u403))
(define-constant err-catalog-limit-reached (err u704))
(define-constant err-invalid-inspector-address (err u705))
(define-constant err-invalid-device-model (err u706))
(define-constant err-invalid-regulatory-standards (err u707))
(define-constant err-invalid-production-batch (err u708))
(define-constant err-invalid-facility-code (err u709))
(define-constant err-invalid-device-id (err u710))

;; System administrator for medical certification
(define-constant system-admin tx-sender)

;; Register medical inspector
(define-public (register-medical-inspector (inspector principal))
  (begin
    ;; Verify sender is system administrator
    (asserts! (is-eq tx-sender system-admin) err-access-denied)
    
    ;; Validate inspector principal
    (asserts! (not (is-eq inspector 'SP000000000000000000002Q6VF78)) err-invalid-inspector-address)
    
    ;; Register inspector in system
    (ok (map-set medical-inspectors inspector true))
  )
)

;; Register medical device
(define-public (register-medical-device 
  (device-model (string-utf8 64)) 
  (regulatory-standards (string-utf8 256)) 
  (production-batch uint) 
  (facility-code (string-utf8 64)))
  (let
    ((device-id (var-get device-id-counter))
     (manufacturer tx-sender)
     (current-catalog (default-to (list) (map-get? manufacturer-catalog manufacturer))))
    
    ;; Input validation
    (asserts! (> (len device-model) u0) err-invalid-device-model)
    (asserts! (> (len regulatory-standards) u0) err-invalid-regulatory-standards)
    (asserts! (> production-batch u0) err-invalid-production-batch)
    (asserts! (> (len facility-code) u0) err-invalid-facility-code)
    
    ;; Check catalog capacity
    (asserts! (< (len current-catalog) u100) err-catalog-limit-reached)
    
    ;; Store device information
    (map-set medical-devices device-id {
      manufacturer: manufacturer,
      device-model: device-model,
      regulatory-standards: regulatory-standards,
      production-batch: production-batch,
      facility-code: facility-code,
      certified: false
    })
    
    ;; Update manufacturer catalog
    (let 
      ((updated-catalog (unwrap-panic (as-max-len? (concat (list device-id) current-catalog) u100))))
      (map-set manufacturer-catalog manufacturer updated-catalog)
    )
    
    ;; Increment device ID counter
    (var-set device-id-counter (+ device-id u1))
    
    (ok device-id)))

;; Certify medical device
(define-public (certify-medical-device (device-id uint))
  (begin
    ;; Validate device ID
    (asserts! (< device-id (var-get device-id-counter)) err-invalid-device-id)
    
    (let
      ((device (unwrap! (map-get? medical-devices device-id) err-device-not-found)))
      
      ;; Verify sender is authorized inspector
      (asserts! (default-to false (map-get? medical-inspectors tx-sender)) err-unauthorized-inspector)
      
      ;; Update certification status
      (ok (map-set medical-devices device-id (merge device {certified: true})))
    )
  )
)

;; Get medical device information
(define-read-only (get-medical-device (device-id uint))
  (map-get? medical-devices device-id))

;; Get manufacturer catalog
(define-read-only (get-manufacturer-catalog (manufacturer principal))
  (default-to (list) (map-get? manufacturer-catalog manufacturer)))

;; Check inspector authorization
(define-read-only (is-medical-inspector (address principal))
  (default-to false (map-get? medical-inspectors address)))