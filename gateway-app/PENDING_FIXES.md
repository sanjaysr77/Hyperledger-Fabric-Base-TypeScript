# Pending Fixes

## chaincode/iot/iot.go — Fix median calculation

In `shipmentDelivered()` (line ~260), the current code computes the **mean** (average) instead of the **median**.

**Current (wrong):**
```go
sum := 0.0
for _, n := range numbers {
    sum += n
}
median = sum / float64(len(numbers))
```

**Fix:**
```go
// Sort ascending
for i := 0; i < len(numbers); i++ {
    for j := i + 1; j < len(numbers); j++ {
        if numbers[j] < numbers[i] {
            numbers[i], numbers[j] = numbers[j], numbers[i]
        }
    }
}
mid := len(numbers) / 2
if len(numbers)%2 == 0 {
    median = (numbers[mid-1] + numbers[mid]) / 2.0
} else {
    median = numbers[mid]
}
```

> Note: After fixing the chaincode, the chaincode must be repackaged, installed, and committed on all relevant channels before the fix takes effect.
