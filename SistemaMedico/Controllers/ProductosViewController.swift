import UIKit
import CoreData

class ProductosViewController: UIViewController {
    
    // MARK: - Outlets - MANTENEMOS LOS NOMBRES ORIGINALES
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let firebaseService = FirebaseService.shared // ✅ AGREGADO Firebase
    private var productos: [NSManagedObject] = []
    private var productosFiltrados: [NSManagedObject] = []
    private var estaFiltrando = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        configurarObservers()
        cargarProductos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarProductos()
    }
    
    // Configurar observadores NotificationCenter
    private func configurarObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(productosActualizados),
            name: .productosActualizados,
            object: nil
        )
    }
    
    // Método que se ejecuta cuando se notifica actualización
    @objc private func productosActualizados() {
        DispatchQueue.main.async {
            self.cargarProductos()
        }
    }
    
    // Limpiar observador al salir
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Productos"
        
        // ✅ CORREGIDO: Botón de regreso al menú
        let btnBack = UIBarButtonItem(
            title: "🏠 Menú",
            style: .plain,
            target: self,
            action: #selector(regresarAlMenu)
        )
        
        // ✅ NUEVO: Botón de sincronización manual con Firebase
        let btnSync = UIBarButtonItem(
            title: "🔄 Sync",
            style: .plain,
            target: self,
            action: #selector(sincronizarConFirebase)
        )
        
        // Botón para agregar productos
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(agregarProducto)
        )
        
        // ✅ CORREGIDO: Colocar ambos botones en la izquierda
        navigationItem.leftBarButtonItems = [btnBack, btnSync]
        
        searchBar.delegate = self
        searchBar.placeholder = "Buscar productos..."
    }
    
    private func configurarTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // Registrar celda personalizada
        let nib = UINib(nibName: "ProductoTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "ProductoTableViewCell")
        
        // Si no tienes celda personalizada, usa la básica
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CeldaBasica")
    }
    
    // MARK: - Acciones
    @objc private func agregarProducto() {
        let storyboard = UIStoryboard(name: "Productos", bundle: nil)
        if let agregarVC = storyboard.instantiateViewController(withIdentifier: "AgregarProductoViewController") as? AgregarProductoViewController {
            let navController = UINavigationController(rootViewController: agregarVC)
            present(navController, animated: true)
        }
    }
    
    // ✅ NUEVO: Método para regresar al menú principal
    @objc private func regresarAlMenu() {
        navigationController?.popViewController(animated: true)
    }
    
    // ✅ NUEVO: Sincronización manual con Firebase
    @objc private func sincronizarConFirebase() {
        // Actualizar el botón Sync específicamente
        if let leftButtons = navigationItem.leftBarButtonItems,
           leftButtons.count > 1 {
            leftButtons[1].title = "⏳ Sync..."
            leftButtons[1].isEnabled = false
        }
        
        let todosLosProductos = coreDataManager.obtenerProductos()
        
        firebaseService.sincronizarTodosLosProductos(productos: todosLosProductos) { [weak self] result in
            DispatchQueue.main.async {
                // Restaurar el botón Sync
                if let leftButtons = self?.navigationItem.leftBarButtonItems,
                   leftButtons.count > 1 {
                    leftButtons[1].title = "🔄 Sync"
                    leftButtons[1].isEnabled = true
                }
                
                switch result {
                case .success(let mensaje):
                    self?.mostrarExito(mensaje)
                case .failure(let error):
                    self?.mostrarError("Error al sincronizar: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Métodos
    private func cargarProductos() {
        productos = coreDataManager.obtenerProductos().filter { producto in
            return producto.value(forKey: "activo") as? Bool ?? true
        }
        
        if estaFiltrando {
            filtrarProductos()
        }
        
        tableView.reloadData()
    }
    
    private func obtenerProductosParaMostrar() -> [NSManagedObject] {
        return estaFiltrando ? productosFiltrados : productos
    }
    
    private func mostrarDetalleProducto(_ producto: NSManagedObject) {
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        
        let alert = UIAlertController(title: nombre, message: "¿Qué deseas hacer?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📦 Actualizar Stock", style: .default) { _ in
            self.mostrarActualizarStock(producto)
        })
        
        alert.addAction(UIAlertAction(title: "🗑️ Eliminar", style: .destructive) { _ in
            self.confirmarEliminacion(producto)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func confirmarEliminacion(_ producto: NSManagedObject) {
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        
        let alert = UIAlertController(
            title: "Confirmar eliminación",
            message: "¿Estás seguro de que deseas eliminar '\(nombre)'?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { _ in
            // Marcar como inactivo en lugar de eliminar completamente
            producto.setValue(false, forKey: "activo")
            self.coreDataManager.saveContext()
            self.cargarProductos()
            
            // Notificar actualización
            NotificationCenter.default.post(name: .productosActualizados, object: nil)
            
            self.mostrarExito("Producto eliminado correctamente")
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // ✅ NUEVO: Actualizar stock tanto en CoreData como en Firebase
    private func mostrarActualizarStock(_ producto: NSManagedObject) {
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        
        let alert = UIAlertController(title: "Actualizar Stock", message: "Ingrese el nuevo stock para '\(nombre)'", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Nuevo stock"
            textField.keyboardType = .numberPad
            
            let stockActual = producto.value(forKey: "stock") as? Int32 ?? 0
            textField.text = "\(stockActual)"
        }
        
        alert.addAction(UIAlertAction(title: "Actualizar", style: .default) { _ in
            if let textField = alert.textFields?.first,
               let texto = textField.text,
               let nuevoStock = Int32(texto) {
                
                // 1. Actualizar en CoreData
                producto.setValue(nuevoStock, forKey: "stock")
                self.coreDataManager.saveContext()
                self.cargarProductos()
                
                // 2. ✅ NUEVO: Actualizar en Firebase
                self.firebaseService.actualizarProducto(nombre: nombre, nuevoStock: Int(nuevoStock)) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(_):
                            self.mostrarExito("✅ Stock actualizado en CoreData y Firebase")
                        case .failure(let error):
                            self.mostrarError("⚠️ Stock actualizado en CoreData pero falló Firebase: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Notificar actualización para que se actualice el menu principal
                NotificationCenter.default.post(name: .productosActualizados, object: nil)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func filtrarProductos() {
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            estaFiltrando = false
            return
        }
        
        productosFiltrados = productos.filter { producto in
            let nombre = producto.value(forKey: "nombre") as? String ?? ""
            let categoria = producto.value(forKey: "categoria") as? String ?? ""
            return nombre.localizedCaseInsensitiveContains(searchText) ||
                   categoria.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // ✅ NUEVOS: Métodos de UI Helper
    private func mostrarExito(_ mensaje: String) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ProductosViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return obtenerProductosParaMostrar().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CeldaBasica", for: indexPath)
        
        let producto = obtenerProductosParaMostrar()[indexPath.row]
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        let categoria = producto.value(forKey: "categoria") as? String ?? ""
        let stock = producto.value(forKey: "stock") as? Int32 ?? 0
        let stockMinimo = producto.value(forKey: "stockMinimo") as? Int32 ?? 0
        let precio = producto.value(forKey: "precio") as? Double ?? 0.0
        
        // Configurar texto principal
        cell.textLabel?.text = nombre
        cell.detailTextLabel?.text = "\(categoria) • Stock: \(stock) • S/. \(String(format: "%.2f", precio))"
        
        // ✅ NUEVO: Configurar color según stock
        if stock <= stockMinimo {
            cell.textLabel?.textColor = .systemRed
            cell.detailTextLabel?.textColor = .systemRed
            cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        } else {
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.backgroundColor = .systemBackground
        }
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ProductosViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let producto = obtenerProductosParaMostrar()[indexPath.row]
        mostrarDetalleProducto(producto)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let producto = obtenerProductosParaMostrar()[indexPath.row]
            
            let alert = UIAlertController(title: "Confirmar", message: "¿Está seguro de eliminar este producto?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { _ in
                // Marcar como inactivo en lugar de eliminar
                producto.setValue(false, forKey: "activo")
                self.coreDataManager.saveContext()
                self.cargarProductos()
                
                // Notificar actualización
                NotificationCenter.default.post(name: .productosActualizados, object: nil)
            })
            
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
            
            present(alert, animated: true)
        }
    }
}

// MARK: - UISearchBarDelegate
extension ProductosViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            estaFiltrando = false
        } else {
            estaFiltrando = true
            filtrarProductos()
        }
        
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
