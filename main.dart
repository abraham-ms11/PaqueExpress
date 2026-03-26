

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

const String kBaseUrl = 'http://localhost:8000';


const _storage = FlutterSecureStorage();


void main() => runApp(const PaquexpressApp());

class PaquexpressApp extends StatelessWidget {
  const PaquexpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquexpress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0057B8)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}



class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await _storage.read(key: 'jwt');
    if (!mounted) return;
    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaquetesScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': _emailCtrl.text.trim(), 'password': _passCtrl.text},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.write(key: 'jwt', value: data['access_token']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PaquetesScreen()),
        );
      } else {
        setState(() => _error = 'Credenciales incorrectas');
      }
    } catch (_) {
      setState(() => _error = 'No se pudo conectar al servidor');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0057B8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_shipping,
                    size: 64,
                    color: Color(0xFF0057B8),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paquexpress',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0057B8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Iniciar sesión',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class PaquetesScreen extends StatefulWidget {
  const PaquetesScreen({super.key});

  @override
  State<PaquetesScreen> createState() => _PaquetesScreenState();
}

class _PaquetesScreenState extends State<PaquetesScreen> {
  List<dynamic> _paquetes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPaquetes();
  }

  Future<String?> _token() => _storage.read(key: 'jwt');

  Future<void> _cargarPaquetes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse('$kBaseUrl/paquetes?estado=pendiente'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _paquetes = jsonDecode(res.body));
      } else if (res.statusCode == 401) {
        _logout();
      } else {
        setState(() => _error = 'Error al cargar paquetes');
      }
    } catch (_) {
      setState(() => _error = 'Sin conexión al servidor');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'entregado':
        return Colors.green;
      case 'en_ruta':
        return Colors.orange;
      case 'fallido':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Entregas'),
        backgroundColor: const Color(0xFF0057B8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPaquetes,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargarPaquetes,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _paquetes.isEmpty
          ? const Center(child: Text('No tienes entregas pendientes 🎉'))
          : RefreshIndicator(
              onRefresh: _cargarPaquetes,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _paquetes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = _paquetes[i];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0057B8),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        p['codigo_paquete'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['destinatario']),
                          Text(
                            p['direccion'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          p['estado_paquete'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: _colorEstado(p['estado_paquete']),
                        padding: EdgeInsets.zero,
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EntregaScreen(paquete: p),
                        ),
                      ).then((_) => _cargarPaquetes()),
                    ),
                  );
                },
              ),
            ),
    );
  }
}


class EntregaScreen extends StatefulWidget {
  final Map<String, dynamic> paquete;
  const EntregaScreen({super.key, required this.paquete});

  @override
  State<EntregaScreen> createState() => _EntregaScreenState();
}

class _EntregaScreenState extends State<EntregaScreen> {
  File? _foto;
  Uint8List? _fotoBytes;
  Position? _posicion;
  bool _loading = false;
  bool _obteniendo = false;
  String? _mensaje;
  bool _exito = false;
  final _notasCtrl = TextEditingController();
  final _mapController = MapController();

  // ---- Cámara ----
  Future<void> _tomarFoto() async {
  final picker = ImagePicker();
  final img = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 1280,
  );

  if (img != null) {
    if (kIsWeb) {
      final bytes = await img.readAsBytes();
      setState(() => _fotoBytes = bytes);
    } else {
      setState(() => _foto = File(img.path));
    }
  }
}

  // ---- GPS ----
  Future<void> _obtenerUbicacion() async {
    setState(() {
      _obteniendo = true;
      _mensaje = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desactivado');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied)
          throw Exception('Permiso denegado');
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception('Permiso denegado permanentemente');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _posicion = pos;
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      });
    } catch (e) {
      setState(() => _mensaje = e.toString());
    } finally {
      setState(() => _obteniendo = false);
    }
  }

  Future<void> _enviarEntrega() async {
    if (_foto == null && _fotoBytes == null) {
      setState(() => _mensaje = 'Captura una fotografía primero');
      return;
    }
    if (_posicion == null) {
      setState(() => _mensaje = 'Obtén la ubicación GPS primero');
      return;
    }

    setState(() {
      _loading = true;
      _mensaje = null;
    });

    try {
      final token = await _storage.read(key: 'jwt');
      final request = http.MultipartRequest(
  'POST',
  Uri.parse('$kBaseUrl/entregas'),
);

request.headers['Authorization'] = 'Bearer $token';
request.fields['paquete_id'] = widget.paquete['id'].toString();
request.fields['latitud'] = _posicion!.latitude.toString();
request.fields['longitud'] = _posicion!.longitude.toString();
request.fields['notas'] = _notasCtrl.text;


if (kIsWeb) {
  request.files.add(
    http.MultipartFile.fromBytes(
      'foto',
      _fotoBytes!,
      filename: 'foto.jpg',
      contentType: MediaType('image', 'jpeg'),
    ),
  );
} else {
  request.files.add(
    await http.MultipartFile.fromPath(
      'foto',
      _foto!.path,
      contentType: MediaType('image', 'jpeg'),
    ),
  );
}

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        setState(() {
          _exito = true;
          _mensaje = '✅ Paquete entregado correctamente';
        });
      } else {
        final body = jsonDecode(res.body);
        setState(
          () => _mensaje = body['detail'] ?? 'Error al registrar entrega',
        );
      }
    } catch (_) {
      setState(() => _mensaje = 'Error de conexión');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paquete;
    return Scaffold(
      appBar: AppBar(
        title: Text(p['codigo_paquete']),
        backgroundColor: const Color(0xFF0057B8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Info del paquete ----
            Card(
              color: const Color(0xFFE8F0FE),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destinatario: ${p['destinatario']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Dirección: ${p['direccion']}'),
                    Text('Ciudad: ${p['ciudad']}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

         
            const Text(
              'Ubicación del punto de entrega',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _posicion != null
                        ? LatLng(_posicion!.latitude, _posicion!.longitude)
                        : const LatLng(20.5888, -100.3899), // Querétaro
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'mx.paquexpress.app',
                    ),
                    if (_posicion != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _posicion!.latitude,
                              _posicion!.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _obteniendo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  _posicion == null
                      ? 'Obtener ubicación GPS'
                      : 'GPS: ${_posicion!.latitude.toStringAsFixed(5)}, '
                            '${_posicion!.longitude.toStringAsFixed(5)}',
                ),
                onPressed: _obteniendo || _exito ? null : _obtenerUbicacion,
              ),
            ),

            const SizedBox(height: 16),

            // ---- Foto ----
            const Text(
              'Evidencia fotográfica',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _exito ? null : _tomarFoto,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: (_foto != null || _fotoBytes != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _fotoBytes != null
    ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
    : _foto != null
        ? Image.file(_foto!, fit: BoxFit.cover)
        : const SizedBox()
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Toca para tomar foto',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Notas ----
            TextField(
              controller: _notasCtrl,
              maxLines: 2,
              enabled: !_exito,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

           
            if (_mensaje != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _exito ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _exito ? Colors.green : Colors.red),
                ),
                child: Text(
                  _mensaje!,
                  style: TextStyle(
                    color: _exito ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ),

            const SizedBox(height: 16),

           
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Paquete entregado',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: (_loading || _exito) ? null : _enviarEntrega,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _exito
                      ? Colors.green
                      : const Color(0xFF0057B8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            if (_exito) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Volver a mis entregas'),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
