Feature: A scenario counts only after it has been seen failing

  @covers:sg-397.1
  Scenario: A scenario seen red before green counts
    Given a spec repository with one scenario
    And the ledger records that scenario failing against product commit "P1"
    When the gate judges product commit "P2" on which the scenario passes
    Then the verdict is pass
    And the scenario is counted

  @covers:sg-397.2
  Scenario: A scenario whose first result is a pass is rejected
    Given a spec repository with one scenario
    And the ledger records that scenario passing against product commit "P1"
    When the gate judges product commit "P2" on which the scenario passes
    Then the verdict is fail
    And the report names the scenario as never seen red

  @covers:sg-397.3
  Scenario: A scenario with no ledger entry is rejected
    Given a spec repository with one scenario
    And the ledger is empty
    When the gate judges product commit "P1" on which the scenario passes
    Then the verdict is fail
    And the report names the scenario as never seen red
