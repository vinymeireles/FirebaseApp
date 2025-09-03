import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignPage extends StatefulWidget {
 const SignPage({super.key});

 @override
 State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
 final emailText = TextEditingController();
 final passwordText = TextEditingController();
 final confirmText = TextEditingController();

 bool loading = false;
 String? message;
 bool obscure = true;

 @override
 void dispose() {
   emailText.dispose();
   passwordText.dispose();
   confirmText.dispose();
   super.dispose();
 }

 Future<void> _signUp() async {
   final email = emailText.text.trim();
   final password = passwordText.text;
   final confirm = confirmText.text;

   if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
     setState(() => message = 'Preencha e-mail, senha e confirmação.');
     return;
   }
   if (!_isValidEmail(email)) {
     setState(() => message = 'E-mail inválido.');
     return;
   }
   if (password.length < 6) {
     setState(() => message = 'A senha deve ter pelo menos 6 caracteres.');
     return;
   }
   if (password != confirm) {
     setState(() => message = 'As senhas não coincidem.');
     return;
   }

   setState(() {
     loading = true;
     message = null;
   });

   try {
     await FirebaseAuth.instance.createUserWithEmailAndPassword(
       email: email,
       password: password,
     );
     await FirebaseAuth.instance.currentUser?.sendEmailVerification();
     if (!mounted) return;
     Navigator.pop(context);
   } on FirebaseAuthException catch (exception) {
     setState(() => message = _mapCode(exception));
   } catch (exception) {
     setState(() => message = 'Erro: $exception');
   } finally {
     if (mounted) setState(() => loading = false);
   }
 }

 bool _isValidEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);

 String _mapCode(FirebaseAuthException exception) {
   switch (exception.code) {
     case 'email-already-in-use':
       return 'Este e-mail já está em uso.';
     case 'invalid-email':
       return 'E-mail inválido.';
     case 'operation-not-allowed':
       return 'Método de login desabilitado no Firebase.';
     case 'weak-password':
       return 'Senha muito fraca (use 6+ caracteres).';
     default:
       return 'Falha ao criar conta (${exception.code}).';
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Criar conta')),
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
                 obscureText: obscure,
                 decoration: InputDecoration(
                   labelText: 'Senha',
                   suffixIcon: IconButton(
                     icon: Icon(
                       obscure ? Icons.visibility : Icons.visibility_off,
                     ),
                     onPressed: () => setState(() => obscure = !obscure),
                   ),
                 ),
               ),
               const SizedBox(height: 8),
               TextField(
                 controller: confirmText,
                 obscureText: obscure,
                 decoration: const InputDecoration(
                   labelText: 'Confirmar senha',
                 ),
               ),
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: FilledButton(
                   onPressed: loading ? null : _signUp,
                   child: const Text('Criar conta'),
                 ),
               ),
               const SizedBox(height: 8),
               SizedBox(
                 width: double.infinity,
                 child: OutlinedButton(
                   onPressed: loading ? null : () => Navigator.pop(context),
                   child: const Text('Voltar'),
                 ),
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
                     textAlign: TextAlign.center,
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
