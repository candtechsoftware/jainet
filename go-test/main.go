package main

import (
	"log"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
)

// In-memory "database"
var users = make(map[int]map[string]interface{})

func main() {
	// Create Fiber app
	app := fiber.New()

	// Add logger middleware
	app.Use(logger.New())

	// Parse JSON body
	app.Use(func(c *fiber.Ctx) error {
		c.Accepts("application/json")
		return c.Next()
	})

	// POST /users
	app.Post("/users", func(c *fiber.Ctx) error {
		var body map[string]interface{}
		if err := c.BodyParser(&body); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid JSON"})
		}

		id := len(users) + 1
		user := make(map[string]interface{})
		user["id"] = id
		for k, v := range body {
			user[k] = v
		}
		users[id] = user

		return c.Status(201).JSON(user)
	})

	// GET /users/:id
	app.Get("/users/:id", func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid ID"})
		}

		if user, exists := users[id]; exists {
			return c.JSON(user)
		}
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	})

	// GET /users
	app.Get("/users", func(c *fiber.Ctx) error {
		userList := make([]map[string]interface{}, 0, len(users))
		for _, user := range users {
			userList = append(userList, user)
		}
		return c.JSON(userList)
	})

	// DELETE /users/:id
	app.Delete("/users/:id", func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid ID"})
		}

		if _, exists := users[id]; exists {
			delete(users, id)
			return c.JSON(fiber.Map{"message": "User " + strconv.Itoa(id) + " deleted"})
		}
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	})

	// Start server
	log.Println("Express server running on http://localhost:8080")
	log.Fatal(app.Listen(":8080"))
}