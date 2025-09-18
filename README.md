# PestTag: Pesticide Use Registry 🗂️

A comprehensive blockchain-based system for tracking and managing safe pesticide applications in agriculture.

## Overview

PestTag is a decentralized smart contract system built on Stacks blockchain using Clarity language. It provides a transparent and immutable registry for tracking pesticide usage, ensuring agricultural safety compliance, and maintaining detailed records of chemical applications.

## Features

### Core Functionality
- **Pesticide Registration**: Register new pesticides with detailed safety information
- **Application Tracking**: Log pesticide applications with precise location and timing data
- **Safety Monitoring**: Track safety intervals and restricted entry periods
- **Compliance Verification**: Ensure adherence to regulatory guidelines
- **Historical Records**: Maintain immutable logs of all pesticide activities

### Smart Contract Components
1. **Pesticide Registry Contract**: Manages pesticide product database
2. **Application Tracker Contract**: Records and monitors pesticide applications

## Technical Stack

- **Blockchain**: Stacks (STX)
- **Smart Contract Language**: Clarity
- **Development Tool**: Clarinet
- **Testing Framework**: Vitest

## Contract Architecture

### Pesticide Registry (`pesticide-registry.clar`)
- Manages pesticide product information
- Stores safety data and regulatory compliance info
- Handles product registration and updates
- Maintains active/inactive status tracking

### Application Tracker (`application-tracker.clar`) 
- Records individual pesticide applications
- Tracks location, timing, and dosage information
- Manages safety intervals and re-entry periods
- Provides query functionality for compliance checks

## Data Models

### Pesticide Product
```clarity
{
  product-id: uint,
  name: (string-ascii 100),
  active-ingredient: (string-ascii 100),
  manufacturer: principal,
  registration-number: (string-ascii 50),
  safety-interval: uint,
  max-application-rate: uint,
  is-restricted: bool,
  registration-date: uint,
  expiry-date: uint,
  status: (string-ascii 20)
}
```

### Application Record
```clarity
{
  application-id: uint,
  pesticide-id: uint,
  applicator: principal,
  location: (string-ascii 200),
  area-size: uint,
  application-rate: uint,
  application-date: uint,
  weather-conditions: (string-ascii 100),
  equipment-used: (string-ascii 100),
  safety-interval-end: uint,
  compliance-verified: bool
}
```

## Safety Features

- **Rate Limiting**: Prevents excessive application rates
- **Temporal Restrictions**: Enforces minimum intervals between applications
- **Authorization Controls**: Only certified applicators can register applications
- **Compliance Verification**: Automated checks against safety guidelines
- **Audit Trail**: Complete immutable history of all activities

## Getting Started

### Prerequisites
- Node.js (v16+)
- Clarinet CLI
- Stacks Wallet

### Installation
```bash
# Clone the repository
git clone https://github.com/kambuyunana7/pesttag.git
cd pesttag

# Install dependencies
npm install

# Run contract checks
clarinet check

# Run tests
npm test
```

### Development
```bash
# Create new contract
clarinet contract new [contract-name]

# Check contract syntax
clarinet check

# Console for testing
clarinet console
```

## Usage Examples

### Register a Pesticide
```clarity
(contract-call? .pesticide-registry register-pesticide
  "Roundup Pro"
  "Glyphosate"
  "REG-2024-001"
  u72  ;; 72-hour safety interval
  u1000 ;; max rate per hectare
  false ;; not restricted use
  u2555280000) ;; expiry timestamp
```

### Log an Application
```clarity
(contract-call? .application-tracker log-application
  u1  ;; pesticide-id
  "Field A-North Section"
  u500  ;; area in square meters
  u750  ;; application rate
  "Clear, 15°C, Wind 5km/h"
  "Boom Sprayer Model XYZ")
```

## Compliance & Safety

This system is designed to help agricultural operations maintain compliance with:
- EPA pesticide regulations
- State agricultural guidelines
- Organic certification requirements
- Food safety standards
- Worker protection standards

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure contracts pass `clarinet check`
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For issues, questions, or contributions, please visit our GitHub repository or contact the development team.

---

**⚠️ Important**: Always consult with agricultural extension services and regulatory authorities for the most current pesticide use requirements in your jurisdiction.
