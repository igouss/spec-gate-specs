Feature: Every scenario cites an acceptance criterion that exists

  @covers:sg-3zr.1
  Scenario: A scenario without a covers tag is rejected
    Given a spec repository with one passing scenario that has no covers tag
    When the gate judges any product commit
    Then the verdict is fail
    And the report names the untagged scenario

  @covers:sg-3zr.2
  Scenario: A covers tag naming an absent criterion is rejected
    Given a spec repository whose requirements define criterion "x-abc.1"
    And one passing scenario tagged covers "x-abc.2"
    When the gate judges any product commit
    Then the verdict is fail
    And the report names the tag "x-abc.2"
