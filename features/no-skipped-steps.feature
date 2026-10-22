Feature: A skipped or undefined step fails the run

  @covers:sg-zf8.1
  Scenario: An undefined step fails the run
    Given a spec repository with one scenario containing a step no definition matches
    When the gate judges any product commit
    Then the verdict is fail
    And the report names the undefined step and its scenario

  @covers:sg-zf8.2
  Scenario: A run with zero scenarios fails
    Given a spec repository with no scenarios
    When the gate judges any product commit
    Then the verdict is fail
