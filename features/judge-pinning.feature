Feature: spec-gate is judged by a released build

  @covers:sg-i86.1
  Scenario: A judging binary that does not match the pin refuses to run
    Given a spec repository pinning judge checksum "A"
    And a judging binary whose checksum is "B"
    When the gate is asked to judge any product commit
    Then the gate refuses to run
    And the refusal names checksum "A" and checksum "B"
