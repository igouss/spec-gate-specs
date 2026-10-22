Feature: The spec repository decides which specs judge a product commit

  @covers:sg-dop.1
  Scenario: The verdict names both commits
    Given a spec repository whose main branch is at spec commit "S"
    When the gate judges product commit "P"
    Then the verdict names product commit "P"
    And the verdict names spec commit "S"

  @covers:sg-dop.2
  Scenario: A spec ref pinned inside the product is ignored
    Given a spec repository whose main branch is at spec commit "S"
    And product commit "P" contains a file pinning spec commit "S-1"
    When the gate judges product commit "P"
    Then the verdict names spec commit "S"
