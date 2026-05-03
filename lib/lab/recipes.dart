enum Difficulty { easy, medium, hard }

class Ingredient {
  final String name;
  final String amount;

  const Ingredient(this.name, this.amount);
}

class Recipe {
  final String id;
  final String name;
  final Difficulty difficulty;
  final int prepTimeMinutes;
  final List<Ingredient> ingredients;
  final String instructions;
  final bool isVegetarian;

  const Recipe({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.prepTimeMinutes,
    required this.ingredients,
    required this.instructions,
    required this.isVegetarian,
  });
}

final List<Recipe> demoRecipes = [
  const Recipe(
    id: "RCP-001",
    name: "Classic Avocado Toast",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 10,
    ingredients: [
      Ingredient("Avocado", "1"),
      Ingredient("Sourdough", "2 slices"),
    ],
    instructions: "Mash avocado on toasted sourdough. Season heavily.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-002",
    name: "Moroccan Lamb Tagine",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 180,
    ingredients: [
      Ingredient("Lamb", "1kg"),
      Ingredient("Apricots", "100g"),
      Ingredient("Couscous", "250g"),
    ],
    instructions: "Slow cook lamb with spices for 3 hours until tender.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-003",
    name: "Quick Miso Ramen",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 20,
    ingredients: [
      Ingredient("Noodles", "1pk"),
      Ingredient("Miso", "2tbsp"),
      Ingredient("Egg", "1"),
    ],
    instructions: "Whisk miso into dashi, add boiled noodles and toppings.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-004",
    name: "Blueberry Pancakes",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 15,
    ingredients: [
      Ingredient("Flour", "200g"),
      Ingredient("Blueberries", "50g"),
      Ingredient("Milk", "200ml"),
    ],
    instructions:
        "Mix batter, fold in berries, cook until golden bubbles form.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-005",
    name: "Ribeye Steak & Garlic Butter",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 25,
    ingredients: [
      Ingredient("Ribeye", "400g"),
      Ingredient("Butter", "50g"),
      Ingredient("Garlic", "3 cloves"),
    ],
    instructions:
        "Sear steak 4 mins per side. Baste with foaming garlic butter.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-006",
    name: "Garden Summer Salad",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 5,
    ingredients: [
      Ingredient("Lettuce", "1 head"),
      Ingredient("Cucumber", "1"),
      Ingredient("Lemon", "1/2"),
    ],
    instructions: "Toss chopped greens with lemon juice and olive oil.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-007",
    name: "Beef Wellington",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 120,
    ingredients: [
      Ingredient("Beef Fillet", "800g"),
      Ingredient("Puff Pastry", "1 sheet"),
      Ingredient("Mushroom Duxelles", "200g"),
    ],
    instructions:
        "Sear beef, coat in duxelles, wrap in pastry, and bake at 200°C.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-008",
    name: "Cheddar Omelette",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 8,
    ingredients: [Ingredient("Eggs", "3"), Ingredient("Cheddar", "30g")],
    instructions: "Whisk eggs, cook on low heat, fold in cheese.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-009",
    name: "Spaghetti Carbonara",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 20,
    ingredients: [
      Ingredient("Spaghetti", "200g"),
      Ingredient("Guanciale", "100g"),
      Ingredient("Pecorino", "50g"),
    ],
    instructions:
        "Mix hot pasta with egg and cheese mixture; avoid scrambling.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-010",
    name: "Vegan Lentil Soup",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 40,
    ingredients: [
      Ingredient("Lentils", "200g"),
      Ingredient("Carrots", "2"),
      Ingredient("Vegetable Stock", "1L"),
    ],
    instructions: "Simmer lentils and veggies until soft. Blend partially.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-011",
    name: "Shrimp Scampi",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 15,
    ingredients: [
      Ingredient("Shrimp", "12pc"),
      Ingredient("White Wine", "50ml"),
      Ingredient("Parsley", "1 sprig"),
    ],
    instructions: "Sauté shrimp in garlic and wine. Toss with linguine.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-012",
    name: "Wild Mushroom Risotto",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 45,
    ingredients: [
      Ingredient("Arborio Rice", "300g"),
      Ingredient("Porcini", "50g"),
      Ingredient("Parmesan", "40g"),
    ],
    instructions:
        "Add stock ladle by ladle, stirring constantly for creaminess.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-013",
    name: "Chicken Tikka Masala",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 50,
    ingredients: [
      Ingredient("Chicken", "500g"),
      Ingredient("Yogurt", "100g"),
      Ingredient("Tomato Puree", "200ml"),
    ],
    instructions:
        "Marinate chicken, grill, then simmer in spiced tomato sauce.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-014",
    name: "Caprese Skewers",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 10,
    ingredients: [
      Ingredient("Mozzarella", "10 balls"),
      Ingredient("Cherry Tomatoes", "10"),
      Ingredient("Basil", "10 leaves"),
    ],
    instructions: "Thread onto sticks and drizzle with balsamic glaze.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-015",
    name: "Duck à l'Orange",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 90,
    ingredients: [
      Ingredient("Duck Breast", "2"),
      Ingredient("Oranges", "3"),
      Ingredient("Grand Marnier", "20ml"),
    ],
    instructions: "Score duck skin, sear, and serve with a citrus reduction.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-016",
    name: "Banana Bread",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 60,
    ingredients: [
      Ingredient("Bananas", "3 ripe"),
      Ingredient("Walnuts", "50g"),
      Ingredient("Sugar", "100g"),
    ],
    instructions: "Mash bananas, mix with dry ingredients, bake for 50 mins.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-017",
    name: "Seafood Paella",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 70,
    ingredients: [
      Ingredient("Bomba Rice", "400g"),
      Ingredient("Saffron", "1 pinch"),
      Ingredient("Mixed Shellfish", "300g"),
    ],
    instructions:
        "Cook rice with saffron stock; do not stir to form the 'socarrat' crust.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-018",
    name: "Classic Beef Pho",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 360,
    ingredients: [
      Ingredient("Beef Bones", "2kg"),
      Ingredient("Star Anise", "5 pc"),
      Ingredient("Rice Noodles", "400g"),
      Ingredient("Thai Basil", "1 bunch"),
      Ingredient("Bean Sprouts", "100g"),
    ],
    instructions:
        "Simmer bones for 6 hours with charred ginger and onions. Strain and serve over blanched noodles and raw beef slices.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-019",
    name: "Greek Spinach Pie (Spanakopita)",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 65,
    ingredients: [
      Ingredient("Phyllo Pastry", "1 pack"),
      Ingredient("Spinach", "500g"),
      Ingredient("Feta Cheese", "200g"),
      Ingredient("Dill", "1/2 bunch"),
    ],
    instructions:
        "Layer phyllo with butter. Fill with spinach and feta mixture. Bake until golden and flaky.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-020",
    name: "Crispy Pork Belly",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 120,
    ingredients: [
      Ingredient("Pork Belly", "1.5kg"),
      Ingredient("Five Spice", "1 tsp"),
      Ingredient("Vinegar", "1 tbsp"),
      Ingredient("Sea Salt", "2 tbsp"),
    ],
    instructions:
        "Score skin, rub with vinegar and salt. Roast at 240°C for the crackling, then lower to 160°C.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-021",
    name: "Ratatouille",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 90,
    ingredients: [
      Ingredient("Eggplant", "1"),
      Ingredient("Zucchini", "2"),
      Ingredient("Bell Pepper", "2"),
      Ingredient("Tomato Puree", "300ml"),
    ],
    instructions:
        "Thinly slice vegetables and arrange in a spiral pattern over seasoned tomato sauce. Slow bake.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-022",
    name: "Fish Tacos",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 25,
    ingredients: [
      Ingredient("White Fish", "400g"),
      Ingredient("Corn Tortillas", "8"),
      Ingredient("Cabbage Slaw", "200g"),
      Ingredient("Lime", "2"),
    ],
    instructions:
        "Lightly batter and fry fish. Serve in warm tortillas with slaw and a squeeze of lime.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-023",
    name: "Mushroom Stroganoff",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 30,
    ingredients: [
      Ingredient("Mushrooms", "500g"),
      Ingredient("Sour Cream", "150ml"),
      Ingredient("Egg Noodles", "300g"),
      Ingredient("Paprika", "1 tbsp"),
    ],
    instructions:
        "Sauté mushrooms with onions and paprika. Stir in sour cream at the end. Serve over noodles.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-024",
    name: "Butter Chicken",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 45,
    ingredients: [
      Ingredient("Chicken Thighs", "600g"),
      Ingredient("Ghee", "2 tbsp"),
      Ingredient("Cream", "100ml"),
      Ingredient("Cashew Paste", "2 tbsp"),
    ],
    instructions:
        "Cook marinated chicken in a rich, buttery tomato sauce finished with heavy cream.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-025",
    name: "Quinoa Buddha Bowl",
    difficulty: Difficulty.easy,
    prepTimeMinutes: 20,
    ingredients: [
      Ingredient("Quinoa", "200g"),
      Ingredient("Chickpeas", "1 can"),
      Ingredient("Tahini", "2 tbsp"),
      Ingredient("Kale", "100g"),
    ],
    instructions:
        "Assemble cooked quinoa with roasted chickpeas and kale. Drizzle with tahini dressing.",
    isVegetarian: true,
  ),
  const Recipe(
    id: "RCP-026",
    name: "Lobster Thermidor",
    difficulty: Difficulty.hard,
    prepTimeMinutes: 55,
    ingredients: [
      Ingredient("Lobster", "2 tails"),
      Ingredient("Cognac", "30ml"),
      Ingredient("Mustard", "1 tsp"),
      Ingredient("Gruyère", "50g"),
    ],
    instructions:
        "Cook lobster meat in a creamy brandy sauce, return to shell, top with cheese and broil.",
    isVegetarian: false,
  ),
  const Recipe(
    id: "RCP-027",
    name: "Tiramisu",
    difficulty: Difficulty.medium,
    prepTimeMinutes: 40,
    ingredients: [
      Ingredient("Ladyfingers", "24"),
      Ingredient("Mascarpone", "500g"),
      Ingredient("Espresso", "300ml"),
      Ingredient("Cocoa Powder", "2 tbsp"),
    ],
    instructions:
        "Dip ladyfingers in coffee. Layer with mascarpone cream. Refrigerate for at least 6 hours.",
    isVegetarian: true,
  ),
];
