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
        
        // ✅ CORREGIDO: Obtener datos de los campos con conversiones correctas
        let nombre = txtNombre.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let precio = Double(txtPrecio.text!)!
        let stockInt = Int(txtStock.text!)! // ✅ Primero convertir a Int
        let stockMinimoInt = Int(txtStockMinimo.text!)! // ✅ Primero convertir a Int
        
        // ✅ MOSTRAR INDICADOR VISUAL
        mostrarIndicadorCarga(true)
        
        // ✅ NUEVO: Intentar guardar en Firebase primero, luego en CoreData
        let productoFirebase = ProductoFirebase(
            nombre: nombre,
            categoria: categoriaSeleccionada,
            precio: precio,
            descripcion: "Producto médico",
            stock: stockInt, // ✅ Ya es Int
            stockMinimo: stockMinimoInt // ✅ Ya es Int
        )
        
        firebaseService.subirProducto(producto: productoFirebase) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // ✅ Éxito en Firebase, ahora guardar en CoreData
                    self?.guardarEnCoreData(
                        nombre: nombre,
                        categoria: self?.categoriaSeleccionada ?? "Medicamentos",
                        precio: precio,
                        stock: Int32(stockInt), // ✅ Convertir a Int32 para CoreData
                        stockMinimo: Int32(stockMinimoInt), // ✅ Convertir a Int32 para CoreData
                        mensajeExito: "✅ Producto guardado y sincronizado con Firebase exitosamente"
                    )
                    
                case .failure(let error):
                    // ✅ Error en Firebase, pero guardar localmente
                    print("⚠️ Error al sincronizar con Firebase: \(error.localizedDescription)")
                    self?.guardarEnCoreData(
                        nombre: nombre,
                        categoria: self?.categoriaSeleccionada ?? "Medicamentos",
                        precio: precio,
                        stock: Int32(stockInt), // ✅ Convertir a Int32 para CoreData
                        stockMinimo: Int32(stockMinimoInt), // ✅ Convertir a Int32 para CoreData
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
            stock: Int(stock), // ✅ CoreDataManager.crearProducto espera Int
            stockMinimo: Int(stockMinimo) // ✅ CoreDataManager.crearProducto espera Int
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
        
        // ✅ CORREGIDO: Validar stock - convertir a Int primero
        guard let stockTexto = txtStock.text, !stockTexto.isEmpty,
              let stock = Int(stockTexto), stock >= 0 else {
            mostrarError("Por favor ingrese un stock válido")
            return false
        }
        
        // ✅ CORREGIDO: Validar stock mínimo - convertir a Int primero
        guard let stockMinimoTexto = txtStockMinimo.text, !stockMinimoTexto.isEmpty,
              let stockMinimo = Int(stockMinimoTexto), stockMinimo >= 0 else {
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
