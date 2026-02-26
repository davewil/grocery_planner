# Generate meal time solution from selected recipe 

Given I'm on the recipe page
When I select a recipe to be a dish in a meal time solution
Then I am presented with a meal time solution that ensures everyone in the family has a meal they like
And that could include more than one recipe from the family likes list
But prefer meal time solutions with as few recipes as possible
And I am presented with an overview of the meal time solution with the options


Given there is no meal time solution that can ensure everyone is fed
Then I am told that I can't feed everybody
