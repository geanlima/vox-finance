import 'package:flutter/material.dart';
import 'package:vox_finance/v2/widgets/v2_drawer.dart';

class HomePageV2 extends StatelessWidget {
  const HomePageV2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const V2Drawer(),
      appBar: AppBar(title: const Text('VoxFinance V2')),
      body: const Center(child: Text('Home V2')),
    );
  }
}
