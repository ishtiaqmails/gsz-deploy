GSZ=/opt/gsz; cd $GSZ
echo "===== lib/deliver.js : enqueue/compose sequence ====="
grep -nE "enqueue|compose|\.main|\.followup|\.credentials|deliveryMsg|Received|Payment|Confirm|Instruction|Warranty|Login|delay|sleep" lib/deliver.js
echo
echo "===== lib/deliveryMsg.js : structure + headers ====="
grep -nE "return|main|followup|credentials|ORDER|DELIVERED|LOGIN|LINE|Instruction|Warranty|header|footer|function" lib/deliveryMsg.js
echo
echo "===== senders of Received / Payment Confirmed across lib + routes ====="
grep -rnE "Order Received|Received Order|We received|received your order|Payment Confirmed|Payment confirmed|PAYMENT CONFIRMED|payment.*confirm" lib routes 2>/dev/null | head -50
echo
echo "===== wanotify.enqueue signature + delay support ====="
grep -nE "enqueue|next_attempt_at|queued_at|delay|function" lib/wanotify.js 2>/dev/null | head -30
echo DONE
