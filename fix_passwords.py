from main import SessionLocal, Agente, hash_password

db = SessionLocal()

usuarios = db.query(Agente).all()

for u in usuarios:
    u.password_hash = hash_password("123")
    print(f"Actualizado: {u.email}")

db.commit()
db.close()

print("✔ Contraseñas actualizadas")
