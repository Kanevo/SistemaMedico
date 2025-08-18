import UIKit
import CoreData
import Firebase
import FirebaseFirestore

class ProductosViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private var productos: [NSManagedObject] = []
    private var productosFiltrados: [NSManagedObject] = []
    private var estaFiltrando = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        cargarProductos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarProductos()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Productos"
        
        // Botón para agregar productos
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(agregarProducto)
        )
        
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
    
    // MARK: - Métodos
    private func cargarProductos() {
        productos = coreDataManager.obtenerProductos()
        tableView.reloadData()
    }
    
    private func obtenerProductosParaMostrar() -> [NSManagedObject] {
        return estaFiltrando ? productosFiltrados : productos
    }
    
    private func mostrarDetalleProducto(_ producto: NSManagedObject) {
        let alert = UIAlertController(title: "Detalle del Producto", message: nil, preferredStyle: .alert)
        
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        let categoria = producto.value(forKey: "categoria") as? String ?? ""
        let precio = producto.value(forKey: "precio") as? Double ?? 0.0
        let stock = producto.value(forKey: "stock") as? Int32 ?? 0
        let stockMinimo = producto.value(forKey: "stockMinimo") as? Int32 ?? 0
        
        let mensaje = """
        Nombre: \(nombre)
        Categoría: \(categoria)
        Precio: S/. \(String(format: "%.2f", precio))
        Stock actual: \(stock)
        Stock mínimo: \(stockMinimo)
        """
        
        alert.message = mensaje
        
        // Acción para editar stock
        alert.addAction(UIAlertAction(title: "Editar Stock", style: .default) { _ in
            self.editarStockProducto(producto)
        })
        
        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func editarStockProducto(_ producto: NSManagedObject) {
        let alert = UIAlertController(title: "Editar Stock", message: "Ingrese el nuevo stock", preferredStyle: .alert)
        
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
                self.coreDataManager.actualizarStockProducto(producto: producto, nuevoStock: nuevoStock)
                self.cargarProductos()
                self.mostrarExito("Stock actualizado correctamente")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
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
        
        // Cambiar color si stock es bajo
        if stock <= stockMinimo {
            cell.textLabel?.textColor = .systemRed
            cell.detailTextLabel?.textColor = .systemRed
        } else {
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.textColor = .secondaryLabel
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
            productosFiltrados = productos.filter { producto in
                let nombre = producto.value(forKey: "nombre") as? String ?? ""
                let categoria = producto.value(forKey: "categoria") as? String ?? ""
                return nombre.localizedCaseInsensitiveContains(searchText) ||
                       categoria.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
