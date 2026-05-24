(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require-builtin helix/core/text)

(require "src/utils.scm")

(provide half-page-up-smooth
         half-page-down-smooth
         page-up-smooth
         page-down-smooth
         goto-next-change-smooth
         goto-prev-change-smooth
         goto-first-change-smooth
         goto-last-change-smooth
         goto-next-diag-smooth
         goto-prev-diag-smooth
         goto-first-diag-smooth
         goto-last-diag-smooth
         goto-next-function-smooth
         goto-prev-function-smooth
         goto-next-class-smooth
         goto-prev-class-smooth
         goto-next-parameter-smooth
         goto-prev-parameter-smooth
         goto-next-comment-smooth
         goto-prev-comment-smooth
         goto-next-test-smooth
         goto-prev-test-smooth
         goto-next-paragraph-smooth
         goto-prev-paragraph-smooth)

(define *active-scroll-id* 0)

(define (at-end-of-document?)
  (let* ([doc-id (editor->doc-id (editor-focus))]
         [rope (editor->text doc-id)]
         [cursor-pos (cursor-position)]
         [doc-length (rope-len-chars rope)])
    (>= cursor-pos (- doc-length 1))))

(define (calculate-delay size)
  (cond
    [(>= size 50) 1]
    [(>= size 40) 2]
    [(>= size 30) 3]
    [(>= size 20) 4]
    [(>= size 10) 5]
    [else 10]))

(define (calculate-step size)
  (ceiling (/ size 20)))

(define (move_up_single)
  (begin
    (move_visual_line_up)
    (scroll_up)))

(define (move_down_single)
  (begin
    (when (>= (get-current-line-number) 6)
      (scroll_down))
    (move_visual_line_down)))

(define (start-smooth-scroll direction size)
  (set! *active-scroll-id* (modulo (+ *active-scroll-id* 1) 1000))
  (let ([my-scroll-id *active-scroll-id*]
        [scroll-fn (match direction
                     ['up move_up_single]
                     ['down move_down_single]
                     [_ (error "Invalid scroll direction" direction)])]
        [step (calculate-step size)]
        [delay-ms (calculate-delay size)])
    (let loop ([remaining size])
      (when (and (> remaining 0) (not (and (eq? direction 'down) (at-end-of-document?))))
        (repeat-n-times scroll-fn step)
        (enqueue-thread-local-callback-with-delay delay-ms
                                                  (lambda ()
                                                    (when (= my-scroll-id *active-scroll-id*)
                                                      (loop (- remaining step)))))))))

(define (view-height)
  (let ([area (editor-focused-buffer-area)])
    (if area
        (- (area-height area) 2)
        (error "Unable to retrieve buffer height"))))

(define (half-view-height)
  (ceiling (/ (view-height) 2)))

(define (half-page-up-smooth)
  (start-smooth-scroll 'up (half-view-height)))

(define (half-page-down-smooth)
  (start-smooth-scroll 'down (half-view-height)))

(define (page-up-smooth)
  (start-smooth-scroll 'up (view-height)))

(define (page-down-smooth)
  (start-smooth-scroll 'down (view-height)))

;; --- Smooth goto ---

(define *max-goto-scroll-distance* 200)

(define (smooth-goto goto-fn)
  (let ([start-line (get-current-line-number)])
    (goto-fn)
    (let* ([end-line (get-current-line-number)]
           [delta (- end-line start-line)]
           [abs-delta (abs delta)])
      (when (and (> abs-delta 1) (<= abs-delta *max-goto-scroll-distance*))
        (let ([move-back-fn (if (> delta 0) move_up_single move_down_single)])
          (repeat-n-times move-back-fn abs-delta))
        (start-smooth-scroll (if (> delta 0) 'down 'up) abs-delta)))))

;; Changes
(define (goto-next-change-smooth) (smooth-goto goto_next_change))
(define (goto-prev-change-smooth) (smooth-goto goto_prev_change))
(define (goto-first-change-smooth) (smooth-goto goto_first_change))
(define (goto-last-change-smooth) (smooth-goto goto_last_change))

;; Diagnostics
(define (goto-next-diag-smooth) (smooth-goto goto_next_diag))
(define (goto-prev-diag-smooth) (smooth-goto goto_prev_diag))
(define (goto-first-diag-smooth) (smooth-goto goto_first_diag))
(define (goto-last-diag-smooth) (smooth-goto goto_last_diag))

;; Functions
(define (goto-next-function-smooth) (smooth-goto goto_next_function))
(define (goto-prev-function-smooth) (smooth-goto goto_prev_function))

;; Classes
(define (goto-next-class-smooth) (smooth-goto goto_next_class))
(define (goto-prev-class-smooth) (smooth-goto goto_prev_class))

;; Parameters
(define (goto-next-parameter-smooth) (smooth-goto goto_next_parameter))
(define (goto-prev-parameter-smooth) (smooth-goto goto_prev_parameter))

;; Comments
(define (goto-next-comment-smooth) (smooth-goto goto_next_comment))
(define (goto-prev-comment-smooth) (smooth-goto goto_prev_comment))

;; Tests
(define (goto-next-test-smooth) (smooth-goto goto_next_test))
(define (goto-prev-test-smooth) (smooth-goto goto_prev_test))

;; Paragraphs
(define (goto-next-paragraph-smooth) (smooth-goto goto_next_paragraph))
(define (goto-prev-paragraph-smooth) (smooth-goto goto_prev_paragraph))
