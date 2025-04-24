// Imports for Flutter widgets and input handling.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// A custom input field for entering monetary amounts with a dollar sign prefix.
class AmountInput extends StatefulWidget {
  // Controller for managing the input field's text.
  final TextEditingController controller;
  // Optional validator for input validation.
  final FormFieldValidator<String>? validator;

  // Constructor requiring a controller and allowing an optional validator.
  const AmountInput({
    Key? key,
    required this.controller,
    this.validator,
  }) : super(key: key);

  // Creates the state for the input widget.
  @override
  State<AmountInput> createState() => _AmountInputState();
}

// State class for the AmountInput widget.
class _AmountInputState extends State<AmountInput> {
  // Builds the input field with a dollar sign prefix.
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Positions the dollar sign to the left of the input field.
        Positioned(
          left: 0,
          child: const Text(
            '\$',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Text input field for entering the amount
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.number, // Restricts input to numbers (input validation)
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: Colors.white54,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.only(left: 60), 
          ),
          textAlign: TextAlign.center, 
          validator: widget.validator, 
        ),
      ],
    );
  }
}