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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

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

    if (email == "teste@email.com" && password == "123456") {
      final token = "fake_token_123";
      await _secureStorage.write(key: "auth_token", value: token);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              "🎓 Acesso ao Cofrinho",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Senha"),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _login,
              icon: const Icon(Icons.login),
              label: const Text("Entrar"),
            ),
            const SizedBox(height: 20),
            if (_message != null && _message!.isNotEmpty)
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
      _iv = encrypt.IV.fromSecureRandom(16);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Digite seu recado'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _salvarRecado,
              icon: const Icon(Icons.lock),
              label: const Text('Salvar Recado'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _lerRecado,
              icon: const Icon(Icons.visibility),
              label: const Text('Mostrar Recado'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _recriptografar,
              icon: const Icon(Icons.refresh),
              label: const Text('Re-criptografar'),
            ),
            const SizedBox(height: 30),
            if (_recadoCriptografado != null)
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔒 Recado criptografado:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_recadoCriptografado!),
                    ],
                  ),
                ),
              ),
            if (_recadoDescriptografado != null)
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔓 Recado original:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_recadoDescriptografado!),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _voltarAoLogin,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Voltar ao Login'),
            ),
          ],
        ),
      ),
    );
  }
}
