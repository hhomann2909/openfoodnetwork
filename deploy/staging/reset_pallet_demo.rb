# frozen_string_literal: true

# Fork only: run before a demo. Cancels the orders placed during earlier demos in the demo order
# cycle (everything but the prepared "beispiel-..." orders), so the shared pallet is back at 75 %
# and one order of four boxes of oranges confirms the delivery again.
#   bin/rails runner deploy/staging/reset_pallet_demo.rb
order_cycle = OrderCycle.find_by!("name LIKE ?", "%Münsterland (Beispiel)%")
demo_orders = order_cycle.orders.complete.where.not(state: "canceled").
  where.not("email LIKE ?", "beispiel-%@example.org")

count = demo_orders.count
# Cancel quietly: no mails, and the prepared stock of 500 boxes is plenty for many demos.
demo_orders.update_all(state: "canceled")

progress = OrderCycles::PalletProgress.new(order_cycle)
puts "Cancelled #{count} demo order(s). Pallet: #{progress.ordered_weight.to_i} kg of " \
     "#{progress.capacity.to_i} kg (#{(progress.fill * 100).round} %)."
