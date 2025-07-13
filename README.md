# Tokenized Autonomous Medical Appointment Systems

A comprehensive blockchain-based medical appointment management system built with Clarity smart contracts on the Stacks blockchain.

## System Overview

This system consists of five interconnected smart contracts that manage different aspects of medical appointments:

### Core Contracts

1. **Appointment Scheduler** (`appointment-scheduler.clar`)
    - Coordinates healthcare appointments across multiple providers
    - Manages appointment slots and availability
    - Handles appointment booking and cancellation

2. **Insurance Verifier** (`insurance-verifier.clar`)
    - Confirms coverage and pre-authorization requirements
    - Validates insurance eligibility
    - Tracks authorization status

3. **Reminder Manager** (`reminder-manager.clar`)
    - Provides appointment notifications and preparation instructions
    - Manages reminder schedules
    - Tracks notification delivery

4. **Transportation Coordinator** (`transport-coordinator.clar`)
    - Manages medical appointment travel arrangements
    - Coordinates ride scheduling
    - Tracks transportation status

5. **Follow-up Tracker** (`follow-up-tracker.clar`)
    - Ensures completion of recommended treatments and tests
    - Manages follow-up schedules
    - Tracks treatment compliance

## Features

- **Decentralized**: No single point of failure
- **Transparent**: All appointments and verifications on-chain
- **Automated**: Smart contract-based automation
- **Secure**: Blockchain-based security and immutability
- **Tokenized**: Token-based incentive system

## Token Economics

The system uses a native token (TAMS) for:
- Appointment booking fees
- Provider incentives
- Insurance verification rewards
- Transportation payments
- Follow-up completion rewards

## Getting Started

### Prerequisites

- Clarinet CLI
- Stacks wallet
- Node.js (for testing)

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts: \`clarinet deploy\`

### Usage

Each contract can be interacted with independently:

\`\`\`clarity
;; Book an appointment
(contract-call? .appointment-scheduler book-appointment provider-id u1234567890 "General Checkup")

;; Verify insurance
(contract-call? .insurance-verifier verify-coverage patient-id insurance-id)

;; Set reminder
(contract-call? .reminder-manager set-reminder appointment-id u24)
\`\`\`

## Contract Architecture

### Data Structures

- **Appointments**: Stored with provider, patient, time, and status
- **Insurance Records**: Coverage details and authorization status
- **Reminders**: Notification schedules and delivery tracking
- **Transportation**: Ride details and coordination info
- **Follow-ups**: Treatment plans and completion tracking

### Security Features

- Access control for sensitive operations
- Input validation for all functions
- Error handling with descriptive messages
- Reentrancy protection

## Testing

The system includes comprehensive tests using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover:
- Contract deployment
- Function execution
- Error handling
- Edge cases
- Integration scenarios

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For support and questions, please open an issue in the repository.
