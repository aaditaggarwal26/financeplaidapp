import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountInput extends StatefulWidget {
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;

  const AmountInput({
    Key? key,
    required this.controller,
    this.validator,
  }) : super(key: key);

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
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
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
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
