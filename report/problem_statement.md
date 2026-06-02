# Problem Statement

A lending institution needs a data-driven way to identify risky borrowers before loan approval.

This project analyzes LendingClub loan data to predict loan default risk, segment borrowers into risk groups, and estimate expected portfolio loss.

The target variable is created from loan_status:
- Fully Paid = 0
- Charged Off / Default = 1

Current, Late, and Grace Period loans are excluded because their final outcome is unknown.