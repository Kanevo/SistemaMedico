import UIKit
import CoreData
import Firebase
import FirebaseFirestore

class MenuPrincipalViewController: UIViewController {
    
    // MARK: - Outlets
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
    private var yaSeNotifico = false // ← NUEVO: Para evitar bucle de alertas
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarObservers() // ← NUEVO: NotificationCenter
        verificarDatosIniciales()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        actualizarEstadisticas()
        verificarAlertas()
    }
    
    // ✅ NUEVO: Configurar observadores NotificationCenter
    private func configurarObservers() {
        // Escuchar cuando se actualicen productos o pedidos
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(datosActualizados),
            name: .productosActualizados,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(datosActualizados),
            name: .pedidosActualizados,
            object: nil
        )
        
        // Escuchar cuando se envíe un pedido
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pedidoEnviado),
            name: .pedidoEnviado,
            object: nil
        )
    }
    
    // ✅ NUEVO: Método que se ejecuta cuando se actualizan datos
    @objc private func datosActualizados() {
        DispatchQueue.main.async {
            self.actualizarEstadisticas()
            self.verificarAlertas()
        }
    }
    
    // ✅ NUEVO: Método para pedido enviado
    @objc private func pedidoEnviado(notification: Notification) {
        DispatchQueue.main.async {
            self.mostrarExito("📤 Pedido enviado exitosamente a Firebase")
        }
    }
    
    // ✅ NUEVO: Limpiar observadores al salir
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuración de UI
    private func configurarUI() {
        title = "Sistema Médico"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        lblBienvenida.text = "¡Bienvenido al Sistema de Gestión Médica!"
        
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
    
    // MARK: - Acciones
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
    
    @IBAction func sincronizarDatos(_ sender: UIButton) {
        mostrarIndicadorCarga(true)
        
        // Primero inicializar productos médicos en Firebase (solo primera vez)
        firebaseService.inicializarProductosMedicos()
        
        // Luego obtener productos desde Firebase
        firebaseService.obtenerProductosDesdeFirebase { [weak self] result in
            DispatchQueue.main.async {
                self?.mostrarIndicadorCarga(false)
                
                switch result {
                case .success(let productos):
                    self?.sincronizarProductos(productos)
                case .failure(let error):
                    self?.mostrarError("Error al sincronizar con Firebase: \(error.localizedDescription)")
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
        // Crear algunos productos médicos iniciales
        coreDataManager.crearProducto(nombre: "Paracetamol 500mg", categoria: "Medicamentos", precio: 15.50, stock: 100, stockMinimo: 20)
        coreDataManager.crearProducto(nombre: "Jeringas 5ml", categoria: "Insumos", precio: 2.30, stock: 500, stockMinimo: 100)
        coreDataManager.crearProducto(nombre: "Termómetro Digital", categoria: "Equipos", precio: 45.00, stock: 15, stockMinimo: 10)
        coreDataManager.crearProducto(nombre: "Mascarillas N95", categoria: "Insumos", precio: 8.75, stock: 5, stockMinimo: 25)
        coreDataManager.crearProducto(nombre: "Oxímetro de Pulso", categoria: "Equipos", precio: 120.00, stock: 8, stockMinimo: 5)
        coreDataManager.crearProducto(nombre: "Ibuprofeno 400mg", categoria: "Medicamentos", precio: 18.00, stock: 25, stockMinimo: 15)
        coreDataManager.crearProducto(nombre: "Alcohol en Gel", categoria: "Insumos", precio: 12.50, stock: 30, stockMinimo: 20)
        coreDataManager.crearProducto(nombre: "Tensiómetro Digital", categoria: "Equipos", precio: 85.00, stock: 12, stockMinimo: 8)
        
        // ✅ NUEVO: Notificar que se crearon productos iniciales
        NotificationCenter.default.post(name: .productosActualizados, object: nil)
    }
    
    private func actualizarEstadisticas() {
        let productos = coreDataManager.obtenerProductos()
        let pedidos = coreDataManager.obtenerPedidos()
        
        let totalProductos = productos.count
        let totalPedidos = pedidos.count
        
        lblEstadisticas.text = """
        📦 Productos registrados: \(totalProductos)
        📋 Pedidos realizados: \(totalPedidos)
        ☁️ Conectado a Firebase
        """
    }
    
    // ✅ CORREGIDO: Sin bucle infinito de alertas
    private func verificarAlertas() {
        let productosStockBajo = coreDataManager.obtenerProductosStockBajo()
        
        if !productosStockBajo.isEmpty {
            viewAlertas.isHidden = false
            lblAlertas.text = "⚠️ \(productosStockBajo.count) producto(s) médico(s) con stock bajo"
            
            // ✅ CORREGIDO: Solo mostrar alerta una vez
            if !yaSeNotifico {
                yaSeNotifico = true
                mostrarAlertaStockBajo("Se detectaron \(productosStockBajo.count) productos médicos con stock bajo")
            }
        } else {
            viewAlertas.isHidden = true
            yaSeNotifico = false // Resetear para próxima vez
        }
    }
    
    private func sincronizarProductos(_ productos: [ProductoAPI]) {
        var productosNuevos = 0
        
        for producto in productos {
            // Solo agregar si no existe
            let productosExistentes = coreDataManager.obtenerProductos()
            let existe = productosExistentes.contains { existente in
                (existente.value(forKey: "nombre") as? String) == producto.nombre
            }
            
            if !existe {
                coreDataManager.crearProducto(
                    nombre: producto.nombre,
                    categoria: producto.categoria,
                    precio: producto.precio,
                    stock: Int32.random(in: 10...100),
                    stockMinimo: Int32.random(in: 5...25)
                )
                productosNuevos += 1
            }
        }
        
        // ✅ NUEVO: Notificar actualización después de sincronizar
        NotificationCenter.default.post(name: .productosActualizados, object: nil)
        
        actualizarEstadisticas()
        
        if productosNuevos > 0 {
            mostrarExito("✅ \(productosNuevos) productos médicos nuevos sincronizados con Firebase")
        } else {
            mostrarExito("✅ Productos médicos sincronizados con Firebase - Sin productos nuevos")
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
    
    // ✅ NUEVO: Mostrar alerta de stock bajo sin bucle
    private func mostrarAlertaStockBajo(_ mensaje: String) {
        let alert = UIAlertController(title: "⚠️ Alerta de Stock Médico", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ver Productos", style: .default) { _ in
            self.irAProductos(self.btnProductos)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
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
