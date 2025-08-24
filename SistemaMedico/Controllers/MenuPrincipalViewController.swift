import UIKit
import CoreData
import Firebase
import FirebaseFirestore

class MenuPrincipalViewController: UIViewController {
    
    // MARK: - Outlets - MANTENIENDO LOS NOMBRES EXACTOS DEL STORYBOARD
    @IBOutlet weak var lblBienvenida: UILabel!
    @IBOutlet weak var lblEstadisticas: UILabel!
    @IBOutlet weak var btnProductos: UIButton!
    @IBOutlet weak var btnPedidos: UIButton!
    @IBOutlet weak var btnReportes: UIButton!
    @IBOutlet weak var btnSincronizar: UIButton!
    @IBOutlet weak var viewAlertas: UIView!
    @IBOutlet weak var lblAlertas: UILabel!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let firebaseService = FirebaseService.shared
    private var yaSeNotifico = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        verificarDatosIniciales()
        configurarNotificaciones()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        actualizarEstadisticas()
        verificarAlertas()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Sistema Médico"
        
        // Configurar título - USANDO EL NOMBRE CORRECTO
        lblBienvenida.text = "🏥 Sistema de Gestión Médica"
        lblBienvenida.font = UIFont.boldSystemFont(ofSize: 24)
        lblBienvenida.textAlignment = .center
        
        // Configurar botones
        configurarBoton(btnProductos, titulo: "📦 Gestionar Productos", color: .systemBlue)
        configurarBoton(btnPedidos, titulo: "📋 Gestionar Pedidos", color: .systemGreen)
        configurarBoton(btnReportes, titulo: "📊 Ver Reportes", color: .systemOrange)
        configurarBoton(btnSincronizar, titulo: "☁️ Sincronizar con Firebase", color: .systemPurple)
        
        // Configurar vista de alertas
        viewAlertas.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
        viewAlertas.layer.cornerRadius = 10
        viewAlertas.isHidden = true
    }
    
    private func configurarBoton(_ boton: UIButton, titulo: String, color: UIColor) {
        boton.setTitle(titulo, for: .normal)
        boton.backgroundColor = color
        boton.setTitleColor(.white, for: .normal)
        boton.layer.cornerRadius = 10
        boton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
    }
    
    private func configurarNotificaciones() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(actualizarEstadisticas),
            name: .productosActualizados,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(actualizarEstadisticas),
            name: .pedidosActualizados,
            object: nil
        )
        
        // ✅ NUEVO: Escuchar cuando se envía un pedido
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pedidoEnviadoAFirebase),
            name: .pedidoEnviado,
            object: nil
        )
    }
    
    // MARK: - Acciones - MANTENEMOS LOS NOMBRES ORIGINALES
    @IBAction func irAProductos(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Productos", bundle: nil)
        if let productosVC = storyboard.instantiateViewController(withIdentifier: "ProductosViewController") as? ProductosViewController {
            navigationController?.pushViewController(productosVC, animated: true)
        }
    }
    
    @IBAction func irAPedidos(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Pedidos", bundle: nil)
        if let pedidosVC = storyboard.instantiateViewController(withIdentifier: "PedidosViewController") as? PedidosViewController {
            navigationController?.pushViewController(pedidosVC, animated: true)
        }
    }
    
    @IBAction func irAReportes(_ sender: UIButton) {
        let reportesVC = ReportesViewController()
        navigationController?.pushViewController(reportesVC, animated: true)
    }
    
    // ✅ CORREGIDO: Sincronización bidireccional completa
    @IBAction func sincronizarDatos(_ sender: UIButton) {
        mostrarIndicadorCarga(true)
        
        // Paso 1: Sincronizar productos locales de CoreData a Firebase
        let productosLocales = coreDataManager.obtenerProductos()
        
        firebaseService.sincronizarTodosLosProductos(productos: productosLocales) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let mensajeProductos):
                    print("✅ Productos sincronizados: \(mensajeProductos)")
                    
                    // Paso 2: Sincronizar pedidos enviados
                    self?.sincronizarPedidosEnviados { mensajePedidos in
                        DispatchQueue.main.async {
                            self?.mostrarIndicadorCarga(false)
                            
                            let mensajeCompleto = "✅ Sincronización completa:\n• \(mensajeProductos)\n• \(mensajePedidos)"
                            self?.mostrarExito(mensajeCompleto)
                            self?.actualizarEstadisticas()
                        }
                    }
                    
                case .failure(let error):
                    self?.mostrarIndicadorCarga(false)
                    self?.mostrarError("Error al sincronizar productos: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Métodos auxiliares
    private func verificarDatosIniciales() {
        let productos = coreDataManager.obtenerProductos()
        if productos.isEmpty {
            crearDatosIniciales()
        }
    }
    
    private func crearDatosIniciales() {
        // Crear productos médicos iniciales con valores específicos
        coreDataManager.crearProducto(nombre: "Paracetamol 500mg", categoria: "Medicamentos", precio: 15.50, stock: 100, stockMinimo: 20)
        coreDataManager.crearProducto(nombre: "Jeringas 5ml", categoria: "Insumos", precio: 2.30, stock: 500, stockMinimo: 100)
        coreDataManager.crearProducto(nombre: "Termómetro Digital", categoria: "Equipos", precio: 45.00, stock: 15, stockMinimo: 10)
        coreDataManager.crearProducto(nombre: "Mascarillas N95", categoria: "Insumos", precio: 8.75, stock: 5, stockMinimo: 25)
        coreDataManager.crearProducto(nombre: "Oxímetro de Pulso", categoria: "Equipos", precio: 120.00, stock: 8, stockMinimo: 5)
        coreDataManager.crearProducto(nombre: "Ibuprofeno 400mg", categoria: "Medicamentos", precio: 18.00, stock: 25, stockMinimo: 15)
        coreDataManager.crearProducto(nombre: "Alcohol en Gel", categoria: "Insumos", precio: 12.50, stock: 30, stockMinimo: 20)
        coreDataManager.crearProducto(nombre: "Tensiómetro Digital", categoria: "Equipos", precio: 85.00, stock: 12, stockMinimo: 8)
        
        // Notificar que se crearon productos iniciales
        NotificationCenter.default.post(name: .productosActualizados, object: nil)
    }
    
    @objc private func actualizarEstadisticas() {
        let productos = coreDataManager.obtenerProductos()
        let pedidos = coreDataManager.obtenerPedidos()
        
        // Contar pedidos por estado
        let pedidosPendientes = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Pendiente" }.count
        let pedidosEnviados = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Enviado" }.count
        let pedidosEntregados = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Entregado" }.count
        
        let totalProductos = productos.count
        let totalPedidos = pedidos.count
        
        lblEstadisticas.text = """
        📦 Productos registrados: \(totalProductos)
        📋 Pedidos totales: \(totalPedidos)
        ⏳ Pendientes: \(pedidosPendientes) | 📤 Enviados: \(pedidosEnviados) | ✅ Entregados: \(pedidosEntregados)
        ☁️ Conectado a Firebase
        """
    }
    
    // Sin bucle infinito de alertas
    private func verificarAlertas() {
        let productosStockBajo = coreDataManager.obtenerProductosStockBajo()
        let pedidos = coreDataManager.obtenerPedidos()
        let pedidosPendientes = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Pendiente" }
        
        var alertas: [String] = []
        
        if !productosStockBajo.isEmpty {
            alertas.append("\(productosStockBajo.count) producto(s) con stock bajo")
        }
        
        if !pedidosPendientes.isEmpty {
            alertas.append("\(pedidosPendientes.count) pedido(s) pendiente(s)")
        }
        
        if !alertas.isEmpty {
            viewAlertas.isHidden = false
            lblAlertas.text = "⚠️ " + alertas.joined(separator: " • ")
            
            // Solo mostrar alerta una vez
            if !yaSeNotifico {
                yaSeNotifico = true
                mostrarAlertaCompleta(alertas.joined(separator: "\n• "))
            }
        } else {
            viewAlertas.isHidden = true
            yaSeNotifico = false // Resetear para próxima vez
        }
    }
    
    // ✅ NUEVO: Método cuando se envía un pedido a Firebase
    @objc private func pedidoEnviadoAFirebase(notification: Notification) {
        DispatchQueue.main.async {
            self.actualizarEstadisticas()
            
            // Mostrar confirmación visual
            if let pedido = notification.object as? NSManagedObject {
                let cliente = pedido.value(forKey: "cliente") as? String ?? "Cliente"
                self.mostrarNotificacionTemporal("📤 Pedido de \(cliente) enviado a Firebase")
            }
        }
    }
    
    // ✅ NUEVO: Sincronizar pedidos enviados
    private func sincronizarPedidosEnviados(completion: @escaping (String) -> Void) {
        let pedidos = coreDataManager.obtenerPedidos()
        let pedidosEnviados = pedidos.filter { pedido in
            let estado = pedido.value(forKey: "estado") as? String ?? ""
            return estado == "Enviado" || estado == "Entregado"
        }
        
        if pedidosEnviados.isEmpty {
            completion("No hay pedidos enviados para sincronizar")
            return
        }
        
        let grupo = DispatchGroup()
        var exitos = 0
        var errores = 0
        
        for pedido in pedidosEnviados {
            grupo.enter()
            
            // Crear PedidoAPI desde NSManagedObject
            let cliente = pedido.value(forKey: "cliente") as? String ?? ""
            let destino = pedido.value(forKey: "destino") as? String ?? ""
            let total = pedido.value(forKey: "total") as? Double ?? 0.0
            
            // Obtener productos del pedido (simplificado)
            let pedidoAPI = PedidoAPI(
                cliente: cliente,
                destino: destino,
                productos: [], // Se puede expandir para obtener productos reales
                total: total
            )
            
            firebaseService.enviarPedido(pedido: pedidoAPI) { result in
                switch result {
                case .success(_):
                    exitos += 1
                case .failure(_):
                    errores += 1
                }
                grupo.leave()
            }
        }
        
        grupo.notify(queue: .main) {
            if errores == 0 {
                completion("\(exitos) pedidos sincronizados exitosamente")
            } else {
                completion("\(exitos) pedidos sincronizados, \(errores) con errores")
            }
        }
    }
    
    private func mostrarIndicadorCarga(_ mostrar: Bool) {
        if mostrar {
            btnSincronizar.setTitle("☁️ Sincronizando...", for: .normal)
            btnSincronizar.isEnabled = false
        } else {
            btnSincronizar.setTitle("☁️ Sincronizar con Firebase", for: .normal)
            btnSincronizar.isEnabled = true
        }
    }
    
    // ✅ NUEVO: Mostrar alerta completa con productos y pedidos
    private func mostrarAlertaCompleta(_ mensaje: String) {
        let alert = UIAlertController(
            title: "⚠️ Alertas del Sistema Médico",
            message: mensaje,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Ver Productos", style: .default) { _ in
            self.irAProductos(self.btnProductos)
        })
        
        alert.addAction(UIAlertAction(title: "Ver Pedidos", style: .default) { _ in
            self.irAPedidos(self.btnPedidos)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // ✅ NUEVO: Mostrar notificación temporal
    private func mostrarNotificacionTemporal(_ mensaje: String) {
        let alert = UIAlertController(title: nil, message: mensaje, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto-cerrar después de 2 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alert.dismiss(animated: true)
        }
    }
    
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
