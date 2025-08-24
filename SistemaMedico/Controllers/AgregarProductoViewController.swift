import UIKit

class AgregarProductoViewController: UIViewController {
    
    // MARK: - Outlets - MANTENEMOS LOS NOMBRES ORIGINALES
    @IBOutlet weak var txtNombre: UITextField!
    @IBOutlet weak var pickerCategoria: UIPickerView!
    @IBOutlet weak var txtPrecio: UITextField!
    @IBOutlet weak var txtStock: UITextField!
    @IBOutlet weak var txtStockMinimo: UITextField!
    @IBOutlet weak var btnGuardar: UIButton!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let firebaseService = FirebaseService.shared // ✅ AGREGADO Firebase
    private let categorias = ["Medicamentos", "Equipos", "Insumos", "Dispositivos", "Consumibles"]
    private var categoriaSeleccionada = "Medicamentos"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarPicker()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Nuevo Producto"
        
        // Botones de navegación
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelar)
        )
        
        // Configurar campos de texto
        txtNombre.placeholder = "Nombre del producto"
        txtPrecio.placeholder = "Precio (S/.)"
        txtStock.placeholder = "Stock inicial"
        txtStockMinimo.placeholder = "Stock mínimo"
        
        // Configurar botón guardar
        btnGuardar.backgroundColor = .systemBlue
        btnGuardar.setTitleColor(.white, for: .normal)
        btnGuardar.layer.cornerRadius = 8
    }
    
    private func configurarPicker() {
        pickerCategoria.delegate = self
        pickerCategoria.dataSource = self
    }
    
    // MARK: - Acciones
    @objc private func cancelar() {
        dismiss(animated: true)
    }
    
    @IBAction func guardarProducto(_ sender: UIButton) {
        guard validarCampos() else { return }
        
        // Obtener datos de los campos
        let nombre = txtNombre.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let precio = Double(txtPrecio.text!)!
        let stock = Int32(txtStock.text!)!
        let stockMinimo = Int32(txtStockMinimo.text!)!
        
        // ✅ NUEVO: Crear ProductoFirebase con valores reales de stock
        let productoFirebase = ProductoFirebase(
            id: nil,
            nombre: nombre,
            categoria: categoriaSeleccionada,
            precio: precio,
            descripcion: "Producto médico de alta calidad",
            stock: Int(stock),
            stockMinimo: Int(stockMinimo),
            activo: true,
            fechaCreacion: Date()
        )
        
        // Mostrar indicador de carga
        mostrarIndicadorCarga(true)
        
        // ✅ NUEVO: Primero subir a Firebase, luego a CoreData
        firebaseService.subirProducto(producto: productoFirebase) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let mensaje):
                    print("✅ Firebase exitoso: \(mensaje)")
                    // Si Firebase fue exitoso, guardar en CoreData
                    self?.guardarEnCoreData(
                        nombre: nombre,
                        categoria: self?.categoriaSeleccionada ?? "Medicamentos",
                        precio: precio,
                        stock: stock,
                        stockMinimo: stockMinimo,
                        mensajeExito: "✅ Producto guardado correctamente en CoreData y Firebase"
                    )
                    
                case .failure(let error):
                    // Si Firebase falla, mostrar error pero aún así guardar en CoreData como respaldo
                    print("❌ Error subiendo a Firebase: \(error.localizedDescription)")
                    
                    self?.guardarEnCoreData(
                        nombre: nombre,
                        categoria: self?.categoriaSeleccionada ?? "Medicamentos",
                        precio: precio,
                        stock: stock,
                        stockMinimo: stockMinimo,
                        mensajeExito: "⚠️ Producto guardado localmente. Error al sincronizar con Firebase: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    // ✅ NUEVO: Método separado para guardar en CoreData
    private func guardarEnCoreData(nombre: String, categoria: String, precio: Double, stock: Int32, stockMinimo: Int32, mensajeExito: String) {
        // Guardar en Core Data
        coreDataManager.crearProducto(
            nombre: nombre,
            categoria: categoria,
            precio: precio,
            stock: stock,
            stockMinimo: stockMinimo
        )
        
        mostrarIndicadorCarga(false)
        
        mostrarExito(mensajeExito) {
            // Notificar actualización automática
            NotificationCenter.default.post(name: .productosActualizados, object: nil)
            
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Validación
    private func validarCampos() -> Bool {
        // Validar nombre
        guard let nombre = txtNombre.text, !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            mostrarError("Por favor ingrese el nombre del producto")
            return false
        }
        
        // Validar precio
        guard let precioTexto = txtPrecio.text, !precioTexto.isEmpty,
              let precio = Double(precioTexto), precio > 0 else {
            mostrarError("Por favor ingrese un precio válido")
            return false
        }
        
        // Validar stock
        guard let stockTexto = txtStock.text, !stockTexto.isEmpty,
              let stock = Int32(stockTexto), stock >= 0 else {
            mostrarError("Por favor ingrese un stock válido")
            return false
        }
        
        // Validar stock mínimo
        guard let stockMinimoTexto = txtStockMinimo.text, !stockMinimoTexto.isEmpty,
              let stockMinimo = Int32(stockMinimoTexto), stockMinimo >= 0 else {
            mostrarError("Por favor ingrese un stock mínimo válido")
            return false
        }
        
        return true
    }
    
    // MARK: - UI Helpers
    private func mostrarIndicadorCarga(_ mostrar: Bool) {
        if mostrar {
            btnGuardar.setTitle("⏳ Guardando...", for: .normal)
            btnGuardar.isEnabled = false
        } else {
            btnGuardar.setTitle("💾 Guardar Producto", for: .normal)
            btnGuardar.isEnabled = true
        }
    }
    
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
}

// MARK: - UIPickerViewDataSource
extension AgregarProductoViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categorias.count
    }
}

// MARK: - UIPickerViewDelegate
extension AgregarProductoViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return categorias[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        categoriaSeleccionada = categorias[row]
    }
}
