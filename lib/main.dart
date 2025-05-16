import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xkppdgdcraynrkcrwvsw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhrcHBkZ2RjcmF5bnJrY3J3dnN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDczNTU0OTAsImV4cCI6MjA2MjkzMTQ5MH0.A1_5HDAw0IfF79pwATSFcMN45wu53WWAMae34lX52Oo',
  );

  final storage = const FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token');

  runApp(CofreApp(isLoggedIn: token != null));
}

class CofreApp extends StatelessWidget {
  final bool isLoggedIn;
  const CofreApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cofrinho de Recados',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: isLoggedIn ? const CofrePage() : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _storage = const FlutterSecureStorage();
  String? _mensagem;

  Future<void> _login() async {
    final email = _email.text.trim();
    final senha = _senha.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _mensagem = "Preencha todos os campos.");
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      if (response.session != null) {
        await _storage.write(key: 'auth_token', value: response.session!.accessToken);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CofrePage()));
      } else {
        setState(() => _mensagem = "Email ou senha inválidos.");
      }
    } catch (e) {
      setState(() => _mensagem = "Erro: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔐 Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            TextField(
              controller: _senha,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _login,
              icon: const Icon(Icons.login),
              label: const Text("Entrar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
              },
              child: const Text("Criar conta"),
            ),
            const SizedBox(height: 20),
            if (_mensagem != null)
              Text(
                _mensagem!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _mensagem;

  Future<void> _cadastrar() async {
    final email = _email.text.trim();
    final senha = _senha.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _mensagem = "Preencha todos os campos.");
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: senha,
      );

      if (response.user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      } else {
        setState(() => _mensagem = "Erro ao criar conta.");
      }
    } catch (e) {
      setState(() => _mensagem = "Erro: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📝 Criar Conta")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            TextField(
              controller: _senha,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cadastrar,
              icon: const Icon(Icons.person_add),
              label: const Text("Criar Conta"),
            ),
            const SizedBox(height: 20),
            if (_mensagem != null)
              Text(
                _mensagem!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
          ],
        ),
      ),
    );
  }
}

class CofrePage extends StatefulWidget {
  const CofrePage({super.key});

  @override
  State<CofrePage> createState() => _CofrePageState();
}

class _CofrePageState extends State<CofrePage> {
  final _controller = TextEditingController();
  final _storage = const FlutterSecureStorage();

  late encrypt.Key _key;
  late encrypt.IV _iv;
  late encrypt.Encrypter _encrypter;

  String? _recadoCriptografado;
  String? _recadoDescriptografado;

  @override
  void initState() {
    super.initState();
    _inicializarCriptografia();
  }

  void _inicializarCriptografia() {
    _key = encrypt.Key.fromSecureRandom(32);
    _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  }

  String _criptografar(String texto) {
    final encrypted = _encrypter.encrypt(texto, iv: _iv);
    return encrypted.base64;
  }

  String _descriptografar(String texto) {
    return _encrypter.decrypt64(texto, iv: _iv);
  }

  Future<void> _salvarRecado() async {
    final texto = _controller.text;
    if (texto.isEmpty) return;

    _iv = encrypt.IV.fromSecureRandom(16);
    final criptografado = _criptografar(texto);

    await _storage.write(key: 'recado', value: criptografado);
    await _storage.write(key: 'iv', value: _iv.base64);

    setState(() {
      _recadoCriptografado = criptografado;
      _recadoDescriptografado = null;
    });

    _controller.clear();
  }

  Future<void> _lerRecado() async {
    final criptografado = await _storage.read(key: 'recado');
    final ivBase64 = await _storage.read(key: 'iv');

    if (criptografado == null || ivBase64 == null) return;

    _iv = encrypt.IV.fromBase64(ivBase64);
    final textoOriginal = _descriptografar(criptografado);

    setState(() {
      _recadoDescriptografado = textoOriginal;
    });
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'auth_token');
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📥 Cofrinho de Recados")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "Digite um recado secreto"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _salvarRecado,
              icon: const Icon(Icons.lock),
              label: const Text("Salvar Recado"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _lerRecado,
              icon: const Icon(Icons.visibility),
              label: const Text("Mostrar Recado"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text("Sair"),
            ),
            const SizedBox(height: 30),
            if (_recadoCriptografado != null)
              Text("🔐 Criptografado:\n$_recadoCriptografado", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_recadoDescriptografado != null)
              Text("🔓 Original:\n$_recadoDescriptografado", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
