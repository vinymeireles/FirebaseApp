import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign.dart';
import 'forgot.dart';

class LoginPage extends StatefulWidget {
 const LoginPage({super.key});
 @override
 State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
 final emailText = TextEditingController();
 final passwordText = TextEditingController();
 bool loading = false;
 String? message;

 @override
 void dispose() {
   emailText.dispose();
   passwordText.dispose();
   super.dispose();
 }

 Future<void> _login() async {
   final email = emailText.text.trim();
   final password = passwordText.text;
   if (email.isEmpty || password.isEmpty) {
     setState(() => message = 'Preencha e-mail e senha.');
     return;
   }
   setState(() {
     loading = true;
     message = null;
   });
   try {
     await FirebaseAuth.instance.signInWithEmailAndPassword(
       email: email,
       password: password,
     );
   } on FirebaseAuthException catch (exception) {
     setState(() => message = _mapCode(exception));
   } catch (exception) {
     setState(() => message = 'Erro: $exception');
   } finally {
     if (mounted) setState(() => loading = false);
   }
 }

 String _mapCode(FirebaseAuthException exception) {
   switch (exception.code) {
     case 'invalid-email':
       return 'E-mail inválido.';
     case 'user-not-found':
       return 'Usuário não encontrado.';
     case 'wrong-password':
       return 'Senha incorreta.';
     case 'too-many-requests':
       return 'Muitas tentativas. Tente mais tarde.';
     default:
       return 'Falha na autenticação (${exception.code}).';
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Entrar')),
     body: Center(
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 460),
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             children: [
               TextField(
                 controller: emailText,
                 keyboardType: TextInputType.emailAddress,
                 decoration: const InputDecoration(labelText: 'E-mail'),
               ),
               const SizedBox(height: 8),
               TextField(
                 controller: passwordText,
                 obscureText: true,
                 decoration: const InputDecoration(labelText: 'Senha'),
               ),
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: FilledButton(
                   onPressed: loading ? null : _login,
                   child: const Text('Entrar'),
                 ),
               ),
               const SizedBox(height: 8),
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton(
                       onPressed: loading
                           ? null
                           : () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => const SignPage(),
                                 ),
                               );
                             },
                       child: const Text('Criar conta'),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: TextButton(
                       onPressed: loading
                           ? null
                           : () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => const ForgotPage(),
                                 ),
                               );
                             },
                       child: const Text('Recuperar senha'),
                     ),
                   ),
                 ],
               ),
               if (loading)
                 const Padding(
                   padding: EdgeInsets.only(top: 16),
                   child: CircularProgressIndicator(),
                 ),
               if (message != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 16),
                   child: Text(
                     message!,
                     style: TextStyle(
                       color: Theme.of(context).colorScheme.primary,
                     ),
                   ),
                 ),
             ],
           ),
         ),
       ),
     ),
   );
 }
}
