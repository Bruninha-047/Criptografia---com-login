import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  runApp(const CofreApp());
}

class CofreApp extends StatelessWidget {
  const CofreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cofrinho de Recados',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[200],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// Tela de Login
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _message;

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = "Preencha todos os campos!";
      });
      return;
    }

    // Simulação de login bem-sucedido
    if (email == "teste@email.com" && password == "123456") {
      final token = "fake_token_123";

      // Armazena o token de forma segura
      await _secureStorage.write(key: "auth_token", value: token);

      // Redireciona para a tela principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CofrePage()),
      );
    } else {
      setState(() {
        _message = "Credenciais inválidas!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔐 Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text("Entrar")),
            const SizedBox(height: 20),
            Text(_message ?? "", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

// Tela do Cofrinho de Recados
class CofrePage extends StatefulWidget {
  const CofrePage({super.key});

  @override
  State<CofrePage> createState() => _CofrePageState();
}

class _CofrePageState extends State<CofrePage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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

  Future<void> _inicializarCriptografia() async {
    _key = encrypt.Key.fromSecureRandom(32);
    _iv = encrypt.IV.fromSecureRandom(16);
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

    final criptografado = _criptografar(texto);

    await _secureStorage.write(key: 'recado', value: criptografado);
    await _secureStorage.write(key: 'iv', value: _iv.base64);

    setState(() {
      _recadoCriptografado = criptografado;
      _recadoDescriptografado = null;
    });

    _controller.clear();
  }

  Future<void> _lerRecado() async {
    final criptografado = await _secureStorage.read(key: 'recado');
    final ivBase64 = await _secureStorage.read(key: 'iv');

    if (criptografado == null || ivBase64 == null) return;

    _iv = encrypt.IV.fromBase64(ivBase64);
    final textoOriginal = _descriptografar(criptografado);

    setState(() {
      _recadoDescriptografado = textoOriginal;
    });
  }

  Future<void> _recriptografar() async {
    if (_recadoDescriptografado != null) {
      final recriptografado = _criptografar(_recadoDescriptografado!);
      await _secureStorage.write(key: 'recado', value: recriptografado);
      await _secureStorage.write(key: 'iv', value: _iv.base64);

      setState(() {
        _recadoCriptografado = recriptografado;
        _recadoDescriptografado = null;
      });
    }
  }

  Future<void> _voltarAoLogin() async {
    await _secureStorage.delete(key: "auth_token");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔐 Cofrinho de Recados')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Digite seu recado', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _salvarRecado, icon: const Icon(Icons.lock), label: const Text('Salvar')),
            ElevatedButton.icon(onPressed: _lerRecado, icon: const Icon(Icons.lock_open), label: const Text('Mostrar')),
            ElevatedButton.icon(onPressed: _recriptografar, icon: const Icon(Icons.lock), label: const Text('Re-criptografar')),
            const SizedBox(height: 24),
            if (_recadoCriptografado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔒 Recado criptografado:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_recadoCriptografado!),
                ],
              ),
            if (_recadoDescriptografado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔓 Recado original:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_recadoDescriptografado!),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _voltarAoLogin, icon: const Icon(Icons.exit_to_app), label: const Text('Voltar ao Login')),
          ],
        ),
      ),
    );
  }
}
