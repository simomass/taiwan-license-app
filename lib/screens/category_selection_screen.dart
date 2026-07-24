import 'package:flutter/material.dart';
import '../managers/data_manager.dart';
import 'training_screen.dart';

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = DataManager().getAllCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Category'),
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final count = DataManager().getQuestionsByCategory(category).length;
          
          return ListTile(
            title: Text(category),
            subtitle: Text('$count questions'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrainingScreen(category: category),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
