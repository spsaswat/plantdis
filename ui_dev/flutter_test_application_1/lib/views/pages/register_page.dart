import 'package:flutter/material.dart';
import 'package:flutter_test_application_1/views/widget_tree.dart';
import 'package:flutter_test_application_1/views/widgets/hero_widget.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPwd = TextEditingController();
  TextEditingController controllerConfirmPwd = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    controllerEmail.dispose();
    controllerPwd.dispose();
    controllerConfirmPwd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 30.0,
                children: [
                  HeroWidget(title: "Register"),
                  TextField(
                    controller: controllerEmail,
                    decoration: InputDecoration(
                      hintText: "Username / Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                  TextField(
                    controller: controllerPwd,
                    decoration: InputDecoration(
                      hintText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                  TextField(
                    controller: controllerConfirmPwd,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => onRegisterPressed(),
                    child: Text("Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onRegisterPressed() {
    if (controllerEmail.text == "" ||
        controllerPwd.text == "" ||
        controllerConfirmPwd.text == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid Credentials"),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (controllerPwd.text != controllerConfirmPwd.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password Mismatch"),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) {
            return WidgetTree();
          },
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("User Registered Successfully"),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }
}
