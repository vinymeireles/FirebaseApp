import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPage extends StatefulWidget {
 const ForgotPage({super.key});
 @override
 State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
 final emailText = TextEditingController();
 bool loading = false;
 String? message;

 @override
 void dispose() {
   emailText.dispose();
   super.dispose();
 }

 Future<void> _sendReset() async {
   final email = emailText.text.trim();
   if (email.isEmpty) {
     setState(() => message = 'Informe seu e-mail.');
     return;
   }

   setState(() {
     loading = true;
     message = null;
   });

   try {
     await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
     setState(
       () => message = 'Você receberá um e-mail para redefinir a senha.',
     );
   } on FirebaseAuthException {
     setState(
       () => message = 'Não foi possível enviar agora. Tente mais tarde.',
     );
   } catch (exception) {
     setState(() => message = 'Erro: $exception');
   } finally {
     if (mounted) setState(() => loading = false);
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: const Text('Recuperar senha')),
     body: Center(
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 460),
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             children: [
               const Text(
                 'Digite seu e-mail para receber o link de redefinição de senha.',
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: emailText,
                 keyboardType: TextInputType.emailAddress,
                 decoration: const InputDecoration(labelText: 'E-mail'),
               ),
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: FilledButton(
                   onPressed: loading ? null : _sendReset,
                   child: const Text('Enviar link'),
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
   ); } }
