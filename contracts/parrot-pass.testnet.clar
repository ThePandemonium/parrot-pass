(impl-trait 'ST3QFME3CANQFQNR86TYVKQYCFT7QX4PRXM1V9W6H.sip009-nft-trait.sip009-nft-trait)

;; https://explorer.hiro.so/txid/ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.spff5v?chain=testnet
(define-non-fungible-token spff5v uint)

;; constants
(define-constant DEPLOYER tx-sender)
(define-constant ERR-NO-MORE-NFTS (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-USER (err u102))
(define-constant ERR-LISTING (err u103))
(define-constant ERR-WRONG-COMMISSION (err u104))
(define-constant ERR-NOT-FOUND (err u105))
(define-constant ERR-MINT-LIMIT (err u106))
(define-constant ERR-METADATA-FROZEN (err u107))
(define-constant ERR-NO-MORE-MINTS (err u108))
(define-constant ERR-INVALID-PERCENTAGE (err u109))
(define-constant ERR-CONTRACT-LOCKED (err u110))
(define-constant ERR-PAUSED (err u111))
(define-constant ERR-BURN-FAILED (err u112))
(define-constant ERR-MINT-FAILED (err u113))
(define-constant ERR-NOT-OWNER (err u114))

;; variables
(define-data-var mint-limit uint u1031)
(define-data-var last-id uint u1)
(define-data-var total-price uint u0)
(define-data-var artist-address principal 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7)
(define-data-var burn-address principal 'ST000000000000000000002AMW42H)
(define-data-var ipfs-root (string-ascii 80) "ipfs://ipfs/bafkreie5iadank7yutdfpbvcjvt5qp7hvdzypvso3yj5jd5h7updzkdabm/")
(define-data-var claim-paused bool false)
(define-data-var metadata-frozen bool false)
(define-data-var locked bool false)
(define-data-var license-uri (string-ascii 80) "")
(define-data-var license-name (string-ascii 40) "")
(define-data-var royalty-percent uint u500)

;; public

(define-public (burn-to-redeem-2d (nft-id uint))
    (begin
        (asserts! (is-eq (unwrap! (unwrap! (contract-call? 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.sp2d get-owner nft-id) ERR-NOT-OWNER) ERR-NOT-OWNER) tx-sender) ERR-NOT-OWNER)
        (asserts! (is-ok (contract-call? 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.sp2d transfer nft-id tx-sender (var-get burn-address))) ERR-BURN-FAILED)
        (mint)))

;; This won't work because I forgot to remove the contract sender restriction from the burn function ('ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.sp31d burn).
;;
;;(define-public (burn-to-redeem-3d (nft-id uint))
;;    (begin
;;        (asserts! (is-eq (unwrap! (unwrap! (contract-call? 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.sp31d get-owner nft-id) ERR-NOT-OWNER) ERR-NOT-OWNER) tx-sender) ERR-NOT-OWNER)
;;        (asserts! (is-ok (contract-call? 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.sp31d burn nft-id)) ERR-BURN-FAILED)
;;        (mint)))

;; private

(define-private (mint)
    (let 
        (
            (last-nft-id (var-get last-id))
            (enabled (asserts! (or (is-eq (var-get mint-limit) u0) (<= last-nft-id (var-get mint-limit))) ERR-NO-MORE-NFTS))
            (art-addr (var-get artist-address))
            (id-reached (mint-many-iter last-nft-id))
            (current-balance (get-balance tx-sender))
        )
        (asserts! (is-eq (var-get claim-paused) false) ERR-PAUSED)
        (asserts! (is-eq (var-get locked) false) ERR-CONTRACT-LOCKED)
        (begin
            (var-set last-id id-reached)
            (map-set token-count tx-sender (+ current-balance (- id-reached last-nft-id)))
        )
        (ok id-reached)))

(define-private (mint-many-iter (next-id uint))
    (if (or (is-eq (var-get mint-limit) u0) (<= next-id (var-get mint-limit)))
        (begin
            (unwrap! (nft-mint? spff5v next-id tx-sender) next-id)
            (+ next-id u1)    
        )
        next-id))

;; admin functions

(define-public (lock-contract)
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-NOT-AUTHORIZED)
        (var-set locked true)
        (ok true)))

(define-public (set-artist-address (address principal))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-INVALID-USER)
        (ok (var-set artist-address address))))

(define-public (set-price (price uint))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-INVALID-USER)
        (ok (var-set total-price price))))

(define-public (toggle-pause)
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-INVALID-USER)
        (ok (var-set claim-paused (not (var-get claim-paused))))))

(define-public (set-mint-limit (limit uint))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-INVALID-USER)
        (asserts! (< limit (var-get mint-limit)) ERR-MINT-LIMIT)
        (ok (var-set mint-limit limit))))

(define-public (burn (token-id uint))
    (begin 
        (asserts! (is-owner token-id tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? market token-id)) ERR-LISTING)
        (nft-burn? spff5v token-id tx-sender)))

(define-private (is-owner (token-id uint) (user principal))
    (is-eq user (unwrap! (nft-get-owner? spff5v token-id) false)))

(define-public (set-base-uri (new-base-uri (string-ascii 80)))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get metadata-frozen)) ERR-METADATA-FROZEN)
        (print { notification: "token-metadata-update", payload: { token-class: "nft", contract-id: (as-contract tx-sender) }})
        (var-set ipfs-root new-base-uri)
        (ok true)))

(define-public (freeze-metadata)
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-NOT-AUTHORIZED)
        (var-set metadata-frozen true)
        (ok true)))

;; Non-custodial SIP-009 transfer function
(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? market id)) ERR-LISTING)
        (trnsfr id sender recipient)))

;; read-only functions

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? spff5v token-id)))

(define-read-only (get-last-token-id)
    (ok (- (var-get last-id) u1)))

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get ipfs-root))))

(define-read-only (get-paused)
    (ok (var-get claim-paused)))

(define-read-only (get-price)
    (ok (var-get total-price)))

(define-read-only (get-artist-address)
    (ok (var-get artist-address)))

(define-read-only (get-locked)
    (ok (var-get locked)))

(define-read-only (get-mint-limit)
    (ok (var-get mint-limit)))

(define-read-only (get-license-uri)
    (ok (var-get license-uri)))
  
(define-read-only (get-license-name)
    (ok (var-get license-name)))
  
(define-public (set-license-uri (uri (string-ascii 80)))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-NOT-AUTHORIZED)
        (ok (var-set license-uri uri))))
    
(define-public (set-license-name (name (string-ascii 40)))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-NOT-AUTHORIZED)
        (ok (var-set license-name name))))

;; Non-custodial marketplace extras
(use-trait commission-trait 'ST16JGJD3W4XGTNA6PA66MQMWHHB32V30YCPVT8E7.commission-trait.commission)

(define-map token-count principal uint)
(define-map market uint {price: uint, commission: principal, royalty: uint})

(define-read-only (get-balance (account principal))
    (default-to u0
        (map-get? token-count account)))

(define-private (trnsfr (id uint) (sender principal) (recipient principal))
    (match (nft-transfer? spff5v id sender recipient)
        success
            (let
                ((sender-balance (get-balance sender))
                (recipient-balance (get-balance recipient)))
                    (map-set token-count
                        sender
                        (- sender-balance u1))
                    (map-set token-count
                        recipient
                        (+ recipient-balance u1))
                    (ok success))
        error (err error)))

(define-private (is-sender-owner (id uint))
    (let ((owner (unwrap! (nft-get-owner? spff5v id) false)))
        (or (is-eq tx-sender owner) (is-eq contract-caller owner))))

(define-read-only (get-listing-in-ustx (id uint))
    (map-get? market id))

(define-public (list-in-ustx (id uint) (price uint) (comm-trait <commission-trait>))
    (let ((listing  {price: price, commission: (contract-of comm-trait), royalty: (var-get royalty-percent)}))
        (asserts! (is-sender-owner id) ERR-NOT-AUTHORIZED)
        (map-set market id listing)
        (print (merge listing {a: "list-in-ustx", id: id}))
        (ok true)))

(define-public (unlist-in-ustx (id uint))
    (begin
        (asserts! (is-sender-owner id) ERR-NOT-AUTHORIZED)
        (map-delete market id)
        (print {a: "unlist-in-ustx", id: id})
        (ok true)))

(define-public (buy-in-ustx (id uint) (comm-trait <commission-trait>))
    (let ((owner (unwrap! (nft-get-owner? spff5v id) ERR-NOT-FOUND))
        (listing (unwrap! (map-get? market id) ERR-LISTING))
        (price (get price listing))
        (royalty (get royalty listing)))
    (asserts! (is-eq (contract-of comm-trait) (get commission listing)) ERR-WRONG-COMMISSION)
    (try! (stx-transfer? price tx-sender owner))
    (try! (pay-royalty price royalty))
    (try! (contract-call? comm-trait pay id price))
    (try! (trnsfr id owner tx-sender))
    (map-delete market id)
    (print {a: "buy-in-ustx", id: id})
    (ok true)))

(define-read-only (get-royalty-percent)
    (ok (var-get royalty-percent)))

(define-public (set-royalty-percent (royalty uint))
    (begin
        (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) ERR-INVALID-USER)
        (asserts! (and (>= royalty u0) (<= royalty u1000)) ERR-INVALID-PERCENTAGE)
        (ok (var-set royalty-percent royalty))))

(define-private (pay-royalty (price uint) (royalty uint))
    (let (
        (royalty-amount (/ (* price royalty) u10000))
    )
    (if (and (> royalty-amount u0) (not (is-eq tx-sender (var-get artist-address))))
        (try! (stx-transfer? royalty-amount tx-sender (var-get artist-address)))
        (print false)
    )
    (ok true)))
