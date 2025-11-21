# Meal Planner Voting Feature

## Overview

The voting feature allows household members to democratically select recipes for the upcoming week. Users can vote on their favorite recipes, and after voting concludes, the system automatically creates meal plans for the next week based on the voting results.

## Features

### 1. Voting Sessions
- **Start Voting**: Any household member can initiate a voting session
- **Duration**: Voting sessions last 48 hours by default
- **Status**: Sessions can be `open`, `closed`, or `processed`
- **Single Session**: Only one active voting session allowed per household at a time

### 2. Recipe Selection
- Only recipes marked as "favorites" appear in voting
- All favorite recipes are displayed with:
  - Recipe name and image
  - Description
  - Servings count
  - Difficulty level
  - Current vote count

### 3. Casting Votes
- **During Active Session**: Users can vote on multiple recipes
- **Visual Feedback**: Voted recipes are highlighted
- **Real-time Updates**: Vote counts update live
- **One Vote Per Recipe**: Each user can only vote once per recipe per session

### 4. Session Information
- **Time Remaining**: Live countdown timer showing time left to vote
- **Your Votes**: Count of recipes you've voted for
- **Status**: Current session state (voting in progress/ended)

### 5. Finalizing Results
- **Auto-eligible**: Finalize button appears when voting time expires
- **Winner Selection**: Top voted recipes selected (with tie-breaking via random shuffle)
- **Meal Plan Creation**: System creates dinner meal plans for next 7 days
- **Distribution**: Winners distributed across the week (one per day)

## User Flow

### Starting a Vote
1. Navigate to `/voting` page
2. Click "Start Voting" button
3. System creates a new 48-hour voting session
4. All favorite recipes appear with vote buttons

### Voting
1. Browse displayed favorite recipes
2. Click "Vote" button on desired recipes
3. Button changes to "Voted" to indicate your selection
4. Vote counts update in real-time for all users

### Finalizing
1. Wait for voting period to end (timer reaches 00:00:00)
2. "Finalize" button appears
3. Click "Finalize" to process results
4. System:
   - Tallies votes
   - Selects top recipes
   - Creates meal plans for next week's dinners
   - Shows success message with count of meals scheduled

## Technical Implementation

### Database Schema

#### MealPlanVoteSession
- `id`: UUID primary key
- `starts_at`: Timestamp when voting began
- `ends_at`: Timestamp when voting ends (starts_at + 48 hours)
- `status`: Current state (:open, :closed, :processed)
- `processed_at`: Timestamp when finalized
- `winning_recipe_ids`: Array of winner recipe IDs
- `account_id`: Household identifier

#### MealPlanVoteEntry
- `id`: UUID primary key
- `vote_session_id`: Foreign key to session
- `recipe_id`: Foreign key to recipe voted on
- `user_id`: Foreign key to voter
- `account_id`: Household identifier
- Unique constraint on (vote_session_id, recipe_id, user_id)

### Key Modules

#### `GroceryPlanner.MealPlanning.Voting`
Context module providing:
- `start_vote/2`: Create new voting session
- `open_session/1`: Find active session for household
- `cast_vote/4`: Record a user's vote
- `finalize_session/3`: Process results and create meal plans

#### `GroceryPlannerWeb.VotingLive`
LiveView handling:
- Real-time session state
- Vote casting interactions
- Timer countdown
- Result finalization

### Business Logic

#### Winner Selection Algorithm
1. Group votes by recipe
2. Count votes per recipe
3. Sort by vote count (descending)
4. For ties, randomly shuffle within same vote count
5. Take top N recipes (N = days in next week, typically 7)

#### Meal Plan Distribution
- Start date: Next Monday from current date
- One dinner per day for 7 days
- All servings set to 4 by default
- Recipes distributed in order of voting rank

## Access Control

- All household members can:
  - View voting page
  - Start voting sessions
  - Cast votes
  - Finalize results
- Votes are tenant-isolated (household-scoped)
- Session data is private to household

## UI/UX Highlights

- **Clean Design**: Modern card-based layout for recipes
- **Visual Feedback**: Clear indication of voted recipes
- **Live Updates**: Real-time vote counts and timer
- **Responsive**: Works on mobile and desktop
- **Accessibility**: Proper button labels and ARIA attributes

## Future Enhancements

Potential improvements:
- Configurable voting duration
- Vote removal/change capability
- Multi-week planning
- Meal type selection (breakfast/lunch/dinner)
- Email notifications when voting starts/ends
- Vote history and analytics
- Recipe suggestions based on voting patterns

## Navigation

Access the voting feature via:
- Main navigation: "Voting" link
- Direct URL: `/voting`
