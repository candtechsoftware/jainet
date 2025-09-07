#!/bin/bash

BASE_URL="http://localhost:8080/users"
USER_IDS=()

echo "=== STEP 1: Create 10 users ==="
for i in $(seq 1 10); do
  RESPONSE=$(curl -s -w " [HTTP:%{http_code}]" -X POST $BASE_URL \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"User$i\", \"role\": \"Engineer\"}")
  echo "Created: $RESPONSE"

  # Extract ID from JSON (requires jq)
  ID=$(echo "$RESPONSE" | sed 's/ \[HTTP.*//' | jq -r '.id')
  USER_IDS+=($ID)
done

echo
echo "=== STEP 2: GET each user 100 times ==="
for id in "${USER_IDS[@]}"; do
  echo "Fetching user $id 100x..."
  for j in $(seq 1 100); do
    curl -s -o /dev/null -w "User $id GET $j [HTTP:%{http_code}]\n" \
      -X GET $BASE_URL/$id \
      -H "Accept: application/json"
  done
done

echo
echo "=== STEP 3: Delete all users ==="
for id in "${USER_IDS[@]}"; do
  RESPONSE=$(curl -s -w " [HTTP:%{http_code}]" -X DELETE $BASE_URL/$id \
    -H "Authorization: Bearer TEST_TOKEN")
  echo "Deleted user $id: $RESPONSE"
done

echo
echo "✅ Test complete."
