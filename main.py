# =============================================================
# PAQUEXPRESS API — VERSION CORREGIDA
# =============================================================

from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Enum, DateTime, Text, Numeric, ForeignKey
from sqlalchemy.orm import declarative_base, sessionmaker, Session, relationship
from sqlalchemy.sql import func
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from pydantic import BaseModel
from typing import Optional, List
import shutil, os, uuid
from fastapi.staticfiles import StaticFiles

# ================= CONFIG =================
DATABASE_URL = "mysql+pymysql://root:@localhost:3306/paquexpress"
SECRET_KEY = "clave_super_segura"
ALGORITHM = "HS256"
TOKEN_EXPIRE = 60

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ================= DB =================
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()


class Agente(Base):
    __tablename__ = "agentes"
    id = Column(Integer, primary_key=True)
    nombre = Column(String(100))
    email = Column(String(150), unique=True)
    password_hash = Column(String(255))
    activo = Column(Integer, default=1)

class Paquete(Base):
    __tablename__ = "paquetes"
    id = Column(Integer, primary_key=True)
    codigo_paquete = Column(String(50))
    agente_id = Column(Integer)
    destinatario = Column(String(150))
    direccion = Column(String(300))
    ciudad = Column(String(100))
    estado_paquete = Column(String(50), default="pendiente")

class Entrega(Base):
    __tablename__ = "entregas"
    id = Column(Integer, primary_key=True)
    paquete_id = Column(Integer)
    agente_id = Column(Integer)
    foto_url = Column(String(500))
    latitud = Column(Numeric(10,7))
    longitud = Column(Numeric(10,7))
    notas = Column(Text)

Base.metadata.create_all(bind=engine)


pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2 = OAuth2PasswordBearer(tokenUrl="/auth/login")

def hash_password(p): return pwd_ctx.hash(p)
def verify_password(p, h):
    try:
        return pwd_ctx.verify(p, h)
    except:
        return False

def create_token(data):
    data["exp"] = datetime.utcnow() + timedelta(minutes=TOKEN_EXPIRE)
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

def get_current_agent(token: str = Depends(oauth2), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        agente_id = int(payload.get("sub"))
    except:
        raise HTTPException(status_code=401, detail="Token inválido")

    agente = db.query(Agente).filter(Agente.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=401, detail="No autorizado")
    return agente

# ================= SCHEMAS =================
class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"

# ================= APP =================
app = FastAPI()

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # en desarrollo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================= AUTH =================
@app.post("/auth/login", response_model=TokenOut)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    agente = db.query(Agente).filter(Agente.email == form.username).first()

    if not agente:
        raise HTTPException(status_code=400, detail="Usuario no existe")

    if not verify_password(form.password, agente.password_hash):
        raise HTTPException(status_code=400, detail="Contraseña incorrecta")

    token = create_token({"sub": str(agente.id)})
    return {"access_token": token}

@app.get("/paquetes")
def paquetes(agente=Depends(get_current_agent), db: Session = Depends(get_db)):
    return db.query(Paquete)\
    .filter(Paquete.agente_id == agente.id)\
    .filter(Paquete.estado_paquete == "pendiente")\
    .all()


@app.post("/entregas")
def entrega(
    paquete_id: int = Form(...),
    latitud: float = Form(...),
    longitud: float = Form(...),
    notas: str = Form(None),
    foto: UploadFile = File(None),  
    agente=Depends(get_current_agent),
    db: Session = Depends(get_db)
):
    foto_url = None

    
    if foto:
        filename = f"{uuid.uuid4().hex}.jpg"
        file_path = os.path.join(UPLOAD_DIR, filename)

        with open(file_path, "wb") as f:
            shutil.copyfileobj(foto.file, f)

      
        foto_url = f"/uploads/{filename}"

   
    nueva = Entrega(
        paquete_id=paquete_id,
        agente_id=agente.id,
        foto_url=foto_url,
        latitud=latitud,
        longitud=longitud,
        notas=notas
    )

    db.add(nueva)

    
    paquete = db.query(Paquete).filter(Paquete.id == paquete_id).first()
    if paquete:
        paquete.estado_paquete = "entregado"

    db.commit()

    return {"ok": True}
