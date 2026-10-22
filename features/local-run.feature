Feature: A local run gives feedback and records nothing

  @covers:sg-ubq.1
  Scenario: A local run leaves the ledger unchanged
    Given a spec repository with a ledger
    When a local run judges a working tree
    Then the ledger is byte-identical to before the run

  @covers:sg-ubq.2
  Scenario: A local run posts no commit status
    Given a spec repository
    When a local run judges a working tree
    Then no commit status is posted
