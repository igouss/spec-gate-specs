Feature: A failure report gives the agent what it needs for the next change

  @covers:sg-212.1
  Scenario: A failed assertion reports expected, actual and the driver trace
    Given a spec repository with one scenario expecting total "18.00"
    And a product that returns total "20.00"
    When the gate judges the product
    Then the report entry for that scenario names the failing step
    And the report entry carries expected "18.00" and actual "20.00"
    And the report entry carries the driver request and response
