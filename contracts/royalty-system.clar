;; Concert Royalty System Contract with Enhanced Management Features

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-SOLD-OUT (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))
(define-constant ERR-INVALID-DATE (err u105))
(define-constant ERR-PURCHASE-LIMIT (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant MAX-TICKETS-PER-PURCHASE u10)

;; Data Variables
(define-map artists principal {
    name: (string-ascii 50),
    royalty-percentage: uint,
    tier: uint,
    total-earned: uint
})

(define-map concerts uint {
    name: (string-ascii 100),
    date: uint,
    total-revenue: uint,
    ticket-price: uint,
    total-tickets: uint,
    tickets-sold: uint,
    is-settled: bool,
    status: (string-ascii 20),
    refund-available: bool
})

(define-map concert-artists {concert-id: uint, artist: principal} {
    performance-order: uint,
    payment-status: bool,
    bonus-percentage: uint,
    royalty-earned: uint
})

(define-map ticket-holders {concert-id: uint, holder: principal} {
    quantity: uint,
    claimed: bool,
    purchased-price: uint
})

;; New function: Cancel concert
(define-public (cancel-concert (concert-id uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status concert) "upcoming") ERR-INVALID-STATUS)
        (print {event: "concert-cancelled", concert-id: concert-id})
        (ok (map-set concerts concert-id 
            (merge concert {
                status: "cancelled",
                refund-available: true
            })
        ))
    ))
)

;; New function: Process refund
(define-public (request-refund (concert-id uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
        (holder-info (unwrap! (map-get? ticket-holders {concert-id: concert-id, holder: tx-sender}) ERR-NOT-FOUND))
    )
    (begin
        (asserts! (get refund-available concert) ERR-NOT-AUTHORIZED)
        (asserts! (not (get claimed holder-info)) ERR-ALREADY-CLAIMED)
        (try! (stx-transfer? (get purchased-price holder-info) contract-owner tx-sender))
        (print {event: "refund-processed", concert-id: concert-id, holder: tx-sender, amount: (get purchased-price holder-info)})
        (ok (map-delete ticket-holders {concert-id: concert-id, holder: tx-sender}))
    ))
)

;; Enhanced distribute-royalties function
(define-public (distribute-royalties (concert-id uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
        (total-revenue (get total-revenue concert))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-settled concert)) ERR-NOT-AUTHORIZED)
        (print {
            event: "royalties-distributed",
            concert-id: concert-id,
            revenue: total-revenue,
            date: (unwrap! (get-block-info? time u0) ERR-INVALID-DATE)
        })
        (ok (map-set concerts concert-id 
            (merge concert {
                is-settled: true,
                status: "completed"
            })
        ))
    ))
)

;; New function: Transfer tickets
(define-public (transfer-tickets (concert-id uint) (recipient principal) (quantity uint))
    (let (
        (sender-info (unwrap! (map-get? ticket-holders {concert-id: concert-id, holder: tx-sender}) ERR-NOT-FOUND))
        (recipient-info (default-to {quantity: u0, claimed: false, purchased-price: u0} 
            (map-get? ticket-holders {concert-id: concert-id, holder: recipient})))
    )
    (begin
        (asserts! (>= (get quantity sender-info) quantity) ERR-INVALID-AMOUNT)
        (asserts! (not (get claimed sender-info)) ERR-ALREADY-CLAIMED)
        (print {event: "tickets-transferred", from: tx-sender, to: recipient, quantity: quantity})
        (map-set ticket-holders {concert-id: concert-id, holder: recipient}
            (merge recipient-info {
                quantity: (+ quantity (get quantity recipient-info)),
                purchased-price: (+ (get purchased-price recipient-info) 
                    (* quantity (/ (get purchased-price sender-info) (get quantity sender-info))))
            })
        )
        (ok (map-set ticket-holders {concert-id: concert-id, holder: tx-sender}
            (merge sender-info {
                quantity: (- (get quantity sender-info) quantity),
                purchased-price: (- (get purchased-price sender-info)
                    (* quantity (/ (get purchased-price sender-info) (get quantity sender-info))))
            })
        ))
    ))
)

;; [Previous functions remain unchanged...]
