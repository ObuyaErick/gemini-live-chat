import 'package:flutter/material.dart';
import 'package:webs/extensions/list_extensions.dart';
import 'package:webs/lab/recipes.dart';

class TableDemoScreen extends StatefulWidget {
  const TableDemoScreen({super.key});

  @override
  State<TableDemoScreen> createState() => _TableDemoScreenState();
}

class _TableDemoScreenState extends State<TableDemoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom Animation Demo ${demoRecipes.length}'),
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all()),
            constraints: BoxConstraints(maxHeight: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: FixedColumnWidth(60),
                    1: FixedColumnWidth(250),
                    2: FixedColumnWidth(100),
                    3: FixedColumnWidth(100),
                    4: FixedColumnWidth(100),
                    5: FixedColumnWidth(800),
                    6: FixedColumnWidth(1000),
                  },
                  border: TableBorder.all(),
                  children: [
                    TableRow(
                      children: [
                        ...List.generate(
                          7,
                          (i) => TableCell(child: Text('$i')),
                        ),
                      ],
                    ),
                    ...demoRecipes.mapIndexed(
                      (recipe, index) => TableRow(
                        children: [
                          TableCell(child: Text('${index + 1}')),
                          TableCell(child: Text(recipe.name)),
                          TableCell(child: Text(recipe.difficulty.name)),
                          TableCell(
                            child: Text(recipe.prepTimeMinutes.toString()),
                          ),
                          TableCell(
                            child: Text(recipe.isVegetarian.toString()),
                          ),
                          TableCell(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...recipe.ingredients.map(
                                  (ingredient) => FilterChip.elevated(
                                    showCheckmark: false,
                                    elevation: 2,
                                    selected: true,
                                    label: Text(ingredient.name),
                                    onSelected: (ingredient) {},
                                    shape: RoundedRectangleBorder(
                                      // side: BorderSide(),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TableCell(child: Text(recipe.instructions)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
